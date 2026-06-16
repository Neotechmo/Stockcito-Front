import SwiftUI

@Observable
private class DashboardViewModel {
    var items: [InventorySummary] = []
    var isLoading = false
    var error: String?
    var searchText = ""

    // IA
    var aiSummary: SummaryResponse?
    var isLoadingAI = false
    var aiError: String?

    var filtered: [InventorySummary] {
        searchText.isEmpty ? items : items.filter {
            $0.productName.localizedCaseInsensitiveContains(searchText)
            || ($0.sku?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    var totalItems: Int { items.count }
    var lowStockCount: Int { items.filter { $0.isLow }.count }
    var okStockCount: Int { totalItems - lowStockCount }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do { items = try await APIClient.shared.get("v1/inventory") }
        catch { self.error = error.localizedDescription }
    }

    func loadAISummary() async {
        isLoadingAI = true
        aiError = nil
        defer { isLoadingAI = false }
        do {
            aiSummary = try await APIClient.shared.postJSON(
                "v1/ai/summaries",
                body: SummaryInput(daysBack: 30, maxSentences: 4, language: "español")
            )
        } catch {
            aiError = error.localizedDescription
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var vm = DashboardViewModel()
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // ── Encabezado ────────────────────────────────────
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hola, \(session.currentUser?.name.components(separatedBy: " ").first ?? "usuario") 👋")
                                .font(.title3.bold())
                                .foregroundStyle(Color.stockLight)
                            Text("Resumen de inventario")
                                .font(.subheadline)
                                .foregroundStyle(Color.stockSubtle)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)

                    // ── Métricas ──────────────────────────────────────
                    HStack(spacing: 12) {
                        MetricCard(value: "\(vm.totalItems)",    label: "Productos",  icon: "cube.box.fill",              color: Color.stockSubtle)
                        MetricCard(value: "\(vm.okStockCount)",  label: "En stock",   icon: "checkmark.circle.fill",      color: .green)
                        MetricCard(value: "\(vm.lowStockCount)", label: "Stock bajo", icon: "exclamationmark.triangle.fill",
                                   color: vm.lowStockCount > 0 ? .orange : Color.stockMuted)
                    }
                    .padding(.horizontal)

                    // ── Tarjeta IA ────────────────────────────────────
                    AIInsightCard(vm: vm)
                        .padding(.horizontal)

                    // ── Buscador ──────────────────────────────────────
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Color.stockMuted)
                        TextField("Buscar producto o SKU…", text: $vm.searchText)
                            .foregroundStyle(Color.stockLight).tint(Color.stockLight)
                    }
                    .padding(12)
                    .background(Color.stockCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)

                    // ── Lista ─────────────────────────────────────────
                    if vm.isLoading && vm.items.isEmpty {
                        VStack(spacing: 12) {
                            ProgressView().tint(Color.stockSubtle)
                            Text("Cargando inventario…")
                                .font(.subheadline).foregroundStyle(Color.stockMuted)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 60)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(vm.filtered) { item in
                                InventorySummaryCard(item: item)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 16).padding(.bottom, 8)
            }
            .stockBackground()
            .refreshable { await vm.load() }
            .task { await vm.load() }
            .navigationTitle("Inventario")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showProfile = true } label: {
                        Image(systemName: "person.circle.fill")
                            .font(.title3).foregroundStyle(Color.stockSubtle)
                    }
                }
            }
            .sheet(isPresented: $showProfile) {
                ProfileView().environmentObject(session)
            }
            .errorAlert(error: Binding(get: { vm.error }, set: { vm.error = $0 }))
            .floatingTabBarPadding()
        }
    }
}

// MARK: - Tarjeta de análisis IA

private struct AIInsightCard: View {
    let vm: DashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Encabezado de la tarjeta
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: "sparkles")
                        .font(.subheadline.bold())
                        .foregroundStyle(.purple)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Análisis inteligente")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.stockLight)
                    Text("Diagnóstico basado en tu inventario")
                        .font(.caption2)
                        .foregroundStyle(Color.stockMuted)
                }
                Spacer()
                Button {
                    Task { await vm.loadAISummary() }
                } label: {
                    if vm.isLoadingAI {
                        ProgressView()
                            .tint(Color.stockSubtle)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: vm.aiSummary == nil ? "play.circle.fill" : "arrow.clockwise")
                            .font(.title3)
                            .foregroundStyle(vm.aiSummary == nil ? .purple : Color.stockSubtle)
                    }
                }
                .disabled(vm.isLoadingAI)
            }

            // Contenido
            if vm.isLoadingAI {
                HStack(spacing: 10) {
                    ProgressView().tint(.purple)
                    Text("Analizando inventario…")
                        .font(.subheadline)
                        .foregroundStyle(Color.stockSubtle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)

            } else if let error = vm.aiError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Color.stockSubtle)
                        .lineLimit(2)
                }

            } else if let summary = vm.aiSummary {
                Divider().background(Color.stockElevated)

                Text(summary.summary)
                    .font(.subheadline)
                    .foregroundStyle(Color.stockSubtle)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Spacer()
                    Text("Modelo: \(summary.model)")
                        .font(.caption2)
                        .foregroundStyle(Color.stockMuted)
                }

            } else {
                // Estado vacío — invita a generar
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.stockMuted)
                    Text("Toca ▶ para generar un diagnóstico de tu inventario")
                        .font(.subheadline)
                        .foregroundStyle(Color.stockMuted)
                        .lineLimit(2)
                }
            }
        }
        .padding(16)
        .background(Color.stockCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.purple.opacity(vm.aiSummary != nil ? 0.25 : 0.1), lineWidth: 1)
        )
    }
}

// MARK: - Tarjeta de métrica

private struct MetricCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(value).font(.title2.bold().monospacedDigit()).foregroundStyle(Color.stockLight)
            Text(label).font(.caption).foregroundStyle(Color.stockSubtle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.stockCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Fila de inventario

private struct InventorySummaryCard: View {
    let item: InventorySummary

    private var stockFraction: Double {
        guard item.minimumStock > 0 else { return 1 }
        return min(item.currentStock / item.minimumStock, 2) / 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.productName)
                        .font(.body.bold()).foregroundStyle(Color.stockLight)
                    if let sku = item.sku {
                        Text("SKU: \(sku)").font(.caption).foregroundStyle(Color.stockMuted)
                    }
                }
                Spacer()
                StatusBadge(
                    text: item.isLow ? "Stock bajo" : "OK",
                    color: item.isLow ? .orange : .green
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.stockElevated).frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(item.isLow ? Color.orange : Color.green)
                            .frame(width: geo.size.width * stockFraction, height: 6)
                            .animation(.easeOut, value: stockFraction)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("\(item.currentStock.stockFormatted) \(item.unitOfMeasure)")
                        .font(.caption.monospacedDigit()).foregroundStyle(Color.stockSubtle)
                    Spacer()
                    Text("mín: \(item.minimumStock.stockFormatted)")
                        .font(.caption2).foregroundStyle(Color.stockMuted)
                }
            }
        }
        .padding(14).background(Color.stockCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
