import SwiftUI

@Observable
private class MovementsViewModel {
    var movements: [InventoryMovement] = []
    var products: [Product] = []
    var isLoading = false
    var error: String?
    var searchText = ""

    var filtered: [InventoryMovement] {
        searchText.isEmpty ? movements : movements.filter {
            ($0.productName ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }
    func load() async {
        isLoading = true; defer { isLoading = false }
        do { movements = try await APIClient.shared.get("v1/inventory-movements") }
        catch { self.error = error.localizedDescription }
    }
    func loadProducts() async {
        products = (try? await APIClient.shared.get("v1/products")) ?? []
    }
    func delete(_ m: InventoryMovement) async {
        do {
            try await APIClient.shared.delete("v1/inventory-movements/\(m.id)")
            movements.removeAll { $0.id == m.id }
        } catch { self.error = error.localizedDescription }
    }
}

struct MovementsView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var vm = MovementsViewModel()
    @State private var showForm = false
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Buscador
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Color.stockMuted)
                        TextField("Buscar producto…", text: $vm.searchText)
                            .foregroundStyle(Color.stockLight).tint(Color.stockLight)
                    }
                    .padding(12).background(Color.stockCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14)).padding(.horizontal)

                    // Botón registrar movimiento
                    Button { showForm = true } label: {
                        Label("Registrar movimiento", systemImage: "plus")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.stockElevated)
                            .foregroundStyle(Color.stockSubtle)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)

                    if vm.isLoading && vm.movements.isEmpty {
                        ProgressView().tint(Color.stockSubtle).padding(.top, 60)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(vm.filtered) { movement in
                                MovementCard(movement: movement)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            Task { await vm.delete(movement) }
                                        } label: { Label("Eliminar", systemImage: "trash") }
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 16).padding(.bottom, 8)
            }
            .stockBackground()
            .navigationTitle("Movimientos")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showProfile = true } label: {
                        Image(systemName: "person.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.stockSubtle)
                    }
                }
            }
            .refreshable { await vm.load() }
            .task { await vm.load() }
            .sheet(isPresented: $showForm) {
                MovementFormSheet(vm: vm, currentUserId: session.currentUser?.id ?? 0) { await vm.load() }
            }
            .sheet(isPresented: $showProfile) {
                ProfileView().environmentObject(session)
            }
            .errorAlert(error: Binding(get: { vm.error }, set: { vm.error = $0 }))
            .floatingTabBarPadding()
        }
    }
}

private struct MovementCard: View {
    let movement: InventoryMovement
    private var isEntry: Bool { movement.movementType == "ENTRY" }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isEntry ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: isEntry ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .font(.title3)
                    .foregroundStyle(isEntry ? .green : .red)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(movement.productName ?? "Producto #\(movement.productId)")
                    .font(.body.bold()).foregroundStyle(Color.stockLight).lineLimit(1)
                HStack(spacing: 6) {
                    Text(movement.movementType.movementTypeLabel)
                        .font(.caption2.bold())
                        .foregroundStyle(isEntry ? .green : .red)
                    if let date = movement.movementDate {
                        Text("·").foregroundStyle(Color.stockMuted)
                        Text(date.readableDate).font(.caption2).foregroundStyle(Color.stockMuted)
                    }
                }
                if let notes = movement.notes {
                    Text(notes).font(.caption2).foregroundStyle(Color.stockMuted).lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(isEntry ? "+" : "-")\(movement.quantity.stockFormatted)")
                    .font(.body.bold().monospacedDigit())
                    .foregroundStyle(isEntry ? .green : .red)
                if let after = movement.stockAfter {
                    Text("→ \(after.stockFormatted)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Color.stockMuted)
                }
            }
        }
        .padding(14).background(Color.stockCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct MovementFormSheet: View {
    let vm: MovementsViewModel
    let currentUserId: Int64
    let onSave: () async -> Void

    @State private var selectedProductId: Int64?
    @State private var movementType = "ENTRY"
    @State private var quantity = ""
    @State private var notes = ""
    @State private var isLoading = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    FormSection(title: "Producto") {
                        if vm.products.isEmpty {
                            Text("Sin productos disponibles").foregroundStyle(Color.stockMuted).padding(14)
                        } else {
                            FormField(label: "Producto *") {
                                Picker("Producto", selection: $selectedProductId) {
                                    Text("Selecciona…").tag(Optional<Int64>.none)
                                    ForEach(vm.products) { p in Text(p.name).tag(Optional(p.id)) }
                                }
                                .tint(Color.stockLight)
                                .padding(14).background(Color.stockElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    FormSection(title: "Movimiento") {
                        // Selector tipo
                        HStack(spacing: 0) {
                            ForEach(["ENTRY", "EXIT"], id: \.self) { type in
                                Button { movementType = type } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: type == "ENTRY" ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                        Text(type == "ENTRY" ? "Entrada" : "Salida").font(.subheadline.bold())
                                    }
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .background(movementType == type ? Color.stockMuted : Color.stockElevated)
                                    .foregroundStyle(movementType == type ? Color.stockLight : Color.stockSubtle)
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        FormField(label: "Cantidad *") {
                            TextField("0", text: $quantity).keyboardType(.decimalPad).stockField()
                        }
                        FormField(label: "Notas") {
                            TextField("Notas opcionales", text: $notes, axis: .vertical).lineLimit(2...3).stockField()
                        }
                    }
                }
                .padding(.top, 16).padding(.bottom, 8)
            }
            .stockBackground()
            .navigationTitle("Nuevo movimiento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.foregroundStyle(Color.stockSubtle)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task {
                            guard let productId = selectedProductId else { error = "Selecciona un producto."; return }
                            guard let qty = Double(quantity), qty > 0 else { error = "La cantidad debe ser positiva."; return }
                            isLoading = true; defer { isLoading = false }
                            let input = MovementInput(productId: productId, userId: currentUserId,
                                movementType: movementType, quantity: qty, notes: notes.isEmpty ? nil : notes)
                            do {
                                let _: InventoryMovement = try await APIClient.shared.postJSON("v1/inventory-movements", body: input)
                                await onSave(); dismiss()
                            } catch { self.error = error.localizedDescription }
                        }
                    }
                    .disabled(isLoading).foregroundStyle(Color.stockLight)
                }
            }
            .task { await vm.loadProducts() }
            .errorAlert(error: Binding(get: { error }, set: { error = $0 }))
        }
    }
}

#Preview { MovementsView() }
