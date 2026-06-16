import SwiftUI

@Observable
private class PurchaseRequestsViewModel {
    var requests: [PurchaseRequest] = []
    var products: [Product] = []
    var isLoading = false
    var error: String?
    var statusFilter = "ALL"

    var filtered: [PurchaseRequest] {
        statusFilter == "ALL" ? requests : requests.filter { $0.status == statusFilter }
    }
    func load() async {
        isLoading = true; defer { isLoading = false }
        do { requests = try await APIClient.shared.get("v1/purchase-requests") }
        catch { self.error = error.localizedDescription }
    }
    func loadProducts() async {
        products = (try? await APIClient.shared.get("v1/products")) ?? []
    }
    func delete(_ req: PurchaseRequest) async {
        do {
            try await APIClient.shared.delete("v1/purchase-requests/\(req.id)")
            requests.removeAll { $0.id == req.id }
        } catch { self.error = error.localizedDescription }
    }
    func update(id: Int64, productId: Int64, requestedBy: Int64, quantity: Double, notes: String?) async throws {
        let input = PurchaseRequestInput(productId: productId, requestedBy: requestedBy,
                                         quantity: quantity, notes: notes)
        let updated: PurchaseRequest = try await APIClient.shared.putJSON(
            "v1/purchase-requests/\(id)", body: input)
        if let idx = requests.firstIndex(where: { $0.id == id }) { requests[idx] = updated }
    }
    func updateStatus(id: Int64, status: String, approvedBy: Int64?) async {
        do {
            let updated: PurchaseRequest = try await APIClient.shared.patchJSON(
                "v1/purchase-requests/\(id)/status",
                body: PurchaseStatusInput(status: status, approvedBy: approvedBy)
            )
            if let idx = requests.firstIndex(where: { $0.id == id }) { requests[idx] = updated }
        } catch { self.error = error.localizedDescription }
    }
}

// MARK: - Lista principal

struct PurchaseRequestsView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var vm = PurchaseRequestsViewModel()
    @State private var showForm = false
    @State private var showProfile = false

    private let filters: [(label: String, value: String)] = [
        ("Todos", "ALL"), ("Pendiente", "PENDING"),
        ("Comprado", "PURCHASED"), ("Cancelado", "CANCELLED")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Filtros horizontales
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filters, id: \.value) { filter in
                                Button {
                                    withAnimation(.spring(response: 0.3)) { vm.statusFilter = filter.value }
                                } label: {
                                    Text(filter.label)
                                        .font(.subheadline.bold())
                                        .padding(.horizontal, 16).padding(.vertical, 8)
                                        .background(vm.statusFilter == filter.value ? Color.stockMuted : Color.stockCard)
                                        .foregroundStyle(vm.statusFilter == filter.value ? Color.stockLight : Color.stockSubtle)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Botón nueva solicitud
                    Button { showForm = true } label: {
                        Label("Nueva solicitud", systemImage: "plus")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.stockElevated)
                            .foregroundStyle(Color.stockSubtle)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)

                    if vm.isLoading && vm.requests.isEmpty {
                        ProgressView().tint(Color.stockSubtle).padding(.top, 60)
                    } else if vm.filtered.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "cart").font(.system(size: 40)).foregroundStyle(Color.stockMuted)
                            Text("Sin solicitudes").foregroundStyle(Color.stockSubtle)
                        }
                        .padding(.top, 60)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(vm.filtered) { req in
                                NavigationLink(destination: PurchaseRequestDetailView(
                                    req: req, vm: vm,
                                    currentUserId: session.currentUser?.id ?? 0
                                )) {
                                    PurchaseRequestCard(req: req)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    if req.status == "PENDING" {
                                        Button {
                                            Task { await vm.updateStatus(id: req.id, status: "PURCHASED", approvedBy: session.currentUser?.id) }
                                        } label: { Label("Marcar comprado", systemImage: "checkmark.circle") }
                                        Button {
                                            Task { await vm.updateStatus(id: req.id, status: "CANCELLED", approvedBy: nil) }
                                        } label: { Label("Cancelar", systemImage: "xmark.circle") }
                                    }
                                    Button(role: .destructive) {
                                        Task { await vm.delete(req) }
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
            .navigationTitle("Solicitudes")
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
                PurchaseRequestFormSheet(vm: vm, currentUserId: session.currentUser?.id ?? 0) { await vm.load() }
            }
            .sheet(isPresented: $showProfile) {
                ProfileView().environmentObject(session)
            }
            .errorAlert(error: Binding(get: { vm.error }, set: { vm.error = $0 }))
            .floatingTabBarPadding()
        }
    }
}

// MARK: - Detalle

private struct PurchaseRequestDetailView: View {
    let req: PurchaseRequest
    let vm: PurchaseRequestsViewModel
    let currentUserId: Int64

    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    private var isOwner: Bool { req.requestedBy == currentUserId }
    private var isPending: Bool { req.status == "PENDING" }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // ── Header ────────────────────────────────────────────
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(req.status.purchaseStatusColor.opacity(0.15))
                            .frame(width: 68, height: 68)
                        Image(systemName: req.status == "PURCHASED"
                              ? "checkmark.circle.fill"
                              : req.status == "CANCELLED"
                              ? "xmark.circle.fill" : "cart.fill")
                            .font(.title2)
                            .foregroundStyle(req.status.purchaseStatusColor)
                    }
                    Text(req.productName ?? "Producto #\(req.productId)")
                        .font(.title3.bold())
                        .foregroundStyle(Color.stockLight)
                        .multilineTextAlignment(.center)
                    StatusBadge(text: req.status.purchaseStatusLabel, color: req.status.purchaseStatusColor)
                }
                .frame(maxWidth: .infinity)
                .stockCard(padding: 24)
                .padding(.horizontal)

                // ── Detalle de la solicitud ───────────────────────────
                InfoSection(title: "Solicitud") {
                    InfoRow(label: "Cantidad", value: req.quantity.stockFormatted)
                    InfoRow(label: "Solicitada por", value: req.requestedByName ?? "#\(req.requestedBy)")
                    if let at = req.requestedAt {
                        InfoRow(label: "Fecha", value: at.readableDate)
                    }
                    if let notes = req.notes, !notes.isEmpty {
                        InfoRow(label: "Notas", value: notes)
                    }
                }

                // ── Aprobación (si aplica) ────────────────────────────
                if req.approvedBy != nil || req.approvedByName != nil {
                    InfoSection(title: "Aprobación") {
                        if let name = req.approvedByName {
                            InfoRow(label: "Aprobada por", value: name)
                        }
                        if let at = req.updatedAt {
                            InfoRow(label: "Actualizada", value: at.readableDate)
                        }
                    }
                }

                // ── Acciones de estado (solo PENDING) ─────────────────
                if isPending {
                    VStack(spacing: 10) {
                        Text("ACCIONES".uppercased())
                            .font(.caption.bold())
                            .foregroundStyle(Color.stockMuted)
                            .tracking(1.5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)

                        Button {
                            Task { await vm.updateStatus(id: req.id, status: "PURCHASED", approvedBy: currentUserId); dismiss() }
                        } label: {
                            Label("Marcar como comprado", systemImage: "checkmark.circle.fill")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.green.opacity(0.15))
                                .foregroundStyle(.green)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal)

                        Button {
                            Task { await vm.updateStatus(id: req.id, status: "CANCELLED", approvedBy: nil); dismiss() }
                        } label: {
                            Label("Cancelar solicitud", systemImage: "xmark.circle.fill")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.stockElevated)
                                .foregroundStyle(Color.stockSubtle)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal)
                    }
                }

                // ── Eliminar (solo propietario) ───────────────────────
                if isOwner {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack(spacing: 8) {
                            if isDeleting {
                                ProgressView().tint(.red).scaleEffect(0.8)
                            } else {
                                Image(systemName: "trash")
                            }
                            Text(isDeleting ? "Eliminando…" : "Eliminar solicitud")
                                .font(.subheadline.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.red.opacity(0.12))
                        .foregroundStyle(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)
                    .disabled(isDeleting)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
        .stockBackground()
        .navigationTitle("Solicitud #\(req.id)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            // El propietario puede editar solo si está pendiente
            if isOwner && isPending {
                ToolbarItem(placement: .primaryAction) {
                    Button("Editar") { showEdit = true }
                        .foregroundStyle(Color.stockSubtle)
                }
            }
        }
        .confirmationDialog(
            "¿Eliminar esta solicitud?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                Task {
                    isDeleting = true
                    await vm.delete(req)
                    dismiss()
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
        .sheet(isPresented: $showEdit) {
            PurchaseRequestEditSheet(req: req, vm: vm)
        }
        .errorAlert(error: Binding(get: { error }, set: { error = $0 }))
    }
}

// MARK: - Formulario de edición (solo cantidad y notas)

private struct PurchaseRequestEditSheet: View {
    let req: PurchaseRequest
    let vm: PurchaseRequestsViewModel

    @State private var quantity: String
    @State private var notes: String
    @State private var isLoading = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    init(req: PurchaseRequest, vm: PurchaseRequestsViewModel) {
        self.req = req
        self.vm = vm
        _quantity = State(initialValue: req.quantity.stockFormatted)
        _notes = State(initialValue: req.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Producto (solo lectura)
                    FormSection(title: "Producto") {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.stockElevated)
                                    .frame(width: 36, height: 36)
                                Image(systemName: "cube.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.stockSubtle)
                            }
                            Text(req.productName ?? "Producto #\(req.productId)")
                                .font(.body)
                                .foregroundStyle(Color.stockLight)
                            Spacer()
                            Text("No editable")
                                .font(.caption2)
                                .foregroundStyle(Color.stockMuted)
                        }
                        .padding(14)
                        .background(Color.stockElevated.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    FormSection(title: "Solicitud") {
                        FormField(label: "Cantidad *") {
                            TextField("0", text: $quantity)
                                .keyboardType(.decimalPad)
                                .stockField()
                        }
                        FormField(label: "Notas") {
                            TextField("Notas opcionales", text: $notes, axis: .vertical)
                                .lineLimit(2...4)
                                .stockField()
                        }
                    }
                }
                .padding(.top, 16).padding(.bottom, 8)
            }
            .stockBackground()
            .navigationTitle("Editar solicitud")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.foregroundStyle(Color.stockSubtle)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task {
                            guard let qty = Double(quantity.replacingOccurrences(of: ",", with: ".")), qty > 0
                            else { error = "La cantidad debe ser un número positivo."; return }
                            isLoading = true; defer { isLoading = false }
                            do {
                                try await vm.update(
                                    id: req.id,
                                    productId: req.productId,
                                    requestedBy: req.requestedBy,
                                    quantity: qty,
                                    notes: notes.isEmpty ? nil : notes
                                )
                                dismiss()
                            } catch { self.error = error.localizedDescription }
                        }
                    }
                    .disabled(isLoading)
                    .foregroundStyle(Color.stockLight)
                }
            }
            .errorAlert(error: Binding(get: { error }, set: { error = $0 }))
        }
    }
}

// MARK: - Card

private struct PurchaseRequestCard: View {
    let req: PurchaseRequest

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(req.status.purchaseStatusColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: req.status == "PURCHASED" ? "checkmark.circle.fill" : req.status == "CANCELLED" ? "xmark.circle.fill" : "cart.fill")
                    .foregroundStyle(req.status.purchaseStatusColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(req.productName ?? "Producto #\(req.productId)")
                    .font(.body.bold()).foregroundStyle(Color.stockLight).lineLimit(1)
                Text("Por: \(req.requestedByName ?? "#\(req.requestedBy)")")
                    .font(.caption).foregroundStyle(Color.stockSubtle)
                if let at = req.requestedAt {
                    Text(at.readableDate).font(.caption2).foregroundStyle(Color.stockMuted)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text(req.quantity.stockFormatted)
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(Color.stockLight)
                StatusBadge(text: req.status.purchaseStatusLabel, color: req.status.purchaseStatusColor)
            }
        }
        .padding(14).background(Color.stockCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Formulario de creación

private struct PurchaseRequestFormSheet: View {
    let vm: PurchaseRequestsViewModel
    let currentUserId: Int64
    let onSave: () async -> Void

    @State private var selectedProductId: Int64?
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
                        FormField(label: "Producto *") {
                            Picker("Producto", selection: $selectedProductId) {
                                Text("Selecciona…").tag(Optional<Int64>.none)
                                ForEach(vm.products) { p in Text(p.name).tag(Optional(p.id)) }
                            }
                            .tint(Color.stockLight).padding(14).background(Color.stockElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    FormSection(title: "Solicitud") {
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
            .navigationTitle("Nueva solicitud")
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
                            let input = PurchaseRequestInput(productId: productId, requestedBy: currentUserId,
                                quantity: qty, notes: notes.isEmpty ? nil : notes)
                            do {
                                let _: PurchaseRequest = try await APIClient.shared.postJSON("v1/purchase-requests", body: input)
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
