import SwiftUI

@Observable
private class SuppliersViewModel {
    var suppliers: [Supplier] = []
    var isLoading = false
    var error: String?
    var searchText = ""

    var filtered: [Supplier] {
        searchText.isEmpty ? suppliers : suppliers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || ($0.contactName?.localizedCaseInsensitiveContains(searchText) ?? false)
            || ($0.email?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    func load() async {
        isLoading = true; defer { isLoading = false }
        do { suppliers = try await APIClient.shared.get("v1/suppliers") }
        catch { self.error = error.localizedDescription }
    }
    func delete(_ s: Supplier) async {
        do {
            try await APIClient.shared.delete("v1/suppliers/\(s.id)")
            suppliers.removeAll { $0.id == s.id }
        } catch { self.error = error.localizedDescription }
    }
    func save(id: Int64?, input: SupplierInput) async throws {
        if let id { let _: Supplier = try await APIClient.shared.putJSON("v1/suppliers/\(id)", body: input) }
        else       { let _: Supplier = try await APIClient.shared.postJSON("v1/suppliers", body: input) }
        await load()
    }
}

struct SuppliersView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var vm = SuppliersViewModel()
    @State private var showForm = false
    @State private var editItem: Supplier?
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Buscador
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Color.stockMuted)
                        TextField("Buscar proveedor…", text: $vm.searchText)
                            .foregroundStyle(Color.stockLight).tint(Color.stockLight)
                    }
                    .padding(12).background(Color.stockCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14)).padding(.horizontal)

                    // Botón agregar proveedor
                    Button { showForm = true } label: {
                        Label("Agregar proveedor", systemImage: "plus")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.stockElevated)
                            .foregroundStyle(Color.stockSubtle)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)

                    if vm.isLoading && vm.suppliers.isEmpty {
                        ProgressView().tint(Color.stockSubtle).padding(.top, 60)
                    } else if vm.filtered.isEmpty && !vm.searchText.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "building.2").font(.system(size: 40)).foregroundStyle(Color.stockMuted)
                            Text("Sin resultados").foregroundStyle(Color.stockSubtle)
                        }
                        .padding(.top, 60)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(vm.filtered) { sup in
                                NavigationLink(destination: SupplierDetailView(supplier: sup, vm: vm)) {
                                    SupplierCard(supplier: sup)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button { editItem = sup } label: { Label("Editar", systemImage: "pencil") }
                                    Button(role: .destructive) {
                                        Task { await vm.delete(sup) }
                                    } label: { Label("Eliminar", systemImage: "trash") }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 16).padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.immediately)
            .stockBackground()
            .navigationTitle("Proveedores")
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
            .overlay { if vm.isLoading && vm.suppliers.isEmpty { ProgressView().tint(Color.stockSubtle) } }
            .task { await vm.load() }
            .sheet(isPresented: $showForm) { SupplierFormSheet(supplier: nil, vm: vm) }
            .sheet(item: $editItem) { sup in SupplierFormSheet(supplier: sup, vm: vm) }
            .sheet(isPresented: $showProfile) {
                ProfileView().environmentObject(session)
            }
            .errorAlert(error: Binding(get: { vm.error }, set: { vm.error = $0 }))
            .floatingTabBarPadding()
        }
    }
}

// MARK: - Supplier Detail
private struct SupplierDetailView: View {
    let supplier: Supplier
    let vm: SuppliersViewModel
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // ── Header ───────────────────────────────────────────
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.stockElevated)
                            .frame(width: 68, height: 68)
                        Image(systemName: "building.2.fill")
                            .font(.title2)
                            .foregroundStyle(Color.stockSubtle)
                    }
                    Text(supplier.name)
                        .font(.title3.bold())
                        .foregroundStyle(Color.stockLight)
                        .multilineTextAlignment(.center)
                    if let active = supplier.isActive {
                        StatusBadge(
                            text: active ? "Activo" : "Inactivo",
                            color: active ? .green : Color.stockMuted
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                .stockCard(padding: 24)
                .padding(.horizontal)

                // ── Contacto ─────────────────────────────────────────
                InfoSection(title: "Contacto") {
                    if let contact = supplier.contactName {
                        InfoRow(label: "Persona", value: contact)
                    }
                    if let email = supplier.email {
                        InfoRow(label: "Email", value: email)
                    }
                    if let phone = supplier.phone {
                        InfoRow(label: "Teléfono", value: phone)
                    }
                    if let address = supplier.address {
                        InfoRow(label: "Dirección", value: address)
                    }
                    if supplier.contactName == nil && supplier.email == nil
                        && supplier.phone == nil && supplier.address == nil {
                        InfoRow(label: "Sin datos de contacto", value: "")
                    }
                }

                // ── Notas ─────────────────────────────────────────────
                if let notes = supplier.notes, !notes.isEmpty {
                    InfoSection(title: "Notas") {
                        Text(notes)
                            .font(.subheadline)
                            .foregroundStyle(Color.stockSubtle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    }
                }

                // ── Registro ──────────────────────────────────────────
                InfoSection(title: "Registro") {
                    if let created = supplier.createdAt {
                        InfoRow(label: "Creado", value: created.readableDate)
                    }
                    if let updated = supplier.updatedAt {
                        InfoRow(label: "Actualizado", value: updated.readableDate)
                    }
                    InfoRow(label: "ID", value: "#\(supplier.id)")
                }

                // ── Eliminar ──────────────────────────────────────────
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    HStack(spacing: 8) {
                        if isDeleting {
                            ProgressView().tint(.red).scaleEffect(0.8)
                        } else {
                            Image(systemName: "trash")
                        }
                        Text(isDeleting ? "Eliminando…" : "Eliminar proveedor")
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
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
        .stockBackground()
        .navigationTitle(supplier.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Editar") { showEdit = true }
                    .foregroundStyle(Color.stockSubtle)
            }
        }
        .confirmationDialog(
            "¿Eliminar a \(supplier.name)?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                Task {
                    isDeleting = true
                    await vm.delete(supplier)
                    dismiss()
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
        .sheet(isPresented: $showEdit) {
            SupplierFormSheet(supplier: supplier, vm: vm)
        }
    }
}

// MARK: - Supplier Card
private struct SupplierCard: View {
    let supplier: Supplier

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.stockElevated).frame(width: 44, height: 44)
                Image(systemName: "building.2.fill").foregroundStyle(Color.stockSubtle)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(supplier.name).font(.body.bold()).foregroundStyle(Color.stockLight)
                if let contact = supplier.contactName {
                    Text(contact).font(.caption).foregroundStyle(Color.stockSubtle)
                }
                HStack(spacing: 10) {
                    if let email = supplier.email {
                        Label(email, systemImage: "envelope")
                            .font(.caption2).foregroundStyle(Color.stockMuted).lineLimit(1)
                    }
                    if let phone = supplier.phone {
                        Label(phone, systemImage: "phone")
                            .font(.caption2).foregroundStyle(Color.stockMuted)
                    }
                }
            }
            Spacer()
        }
        .padding(14)
        .background(Color.stockCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Supplier Form
private struct SupplierFormSheet: View {
    let supplier: Supplier?; let vm: SuppliersViewModel
    @State private var name = ""; @State private var contactName = ""
    @State private var email = ""; @State private var phone = ""
    @State private var address = ""; @State private var notes = ""
    @State private var isLoading = false; @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    FormSection(title: "Proveedor") {
                        FormField(label: "Nombre *") { TextField("Nombre del proveedor", text: $name).stockField() }
                        FormField(label: "Persona de contacto") { TextField("Nombre del contacto", text: $contactName).stockField() }
                    }
                    FormSection(title: "Contacto") {
                        FormField(label: "Email") {
                            TextField("correo@proveedor.com", text: $email).keyboardType(.emailAddress).autocapitalization(.none).stockField()
                        }
                        FormField(label: "Teléfono") { TextField("Número telefónico", text: $phone).keyboardType(.phonePad).stockField() }
                        FormField(label: "Dirección") { TextField("Dirección física", text: $address, axis: .vertical).lineLimit(2...3).stockField() }
                    }
                    FormSection(title: "Notas") {
                        FormField(label: "Notas adicionales") {
                            TextField("Información adicional", text: $notes, axis: .vertical).lineLimit(2...4).stockField()
                        }
                    }
                }
                .padding(.top, 16)
            }
            .scrollDismissesKeyboard(.immediately)
            .keyboardDoneToolbar()
            .stockBackground()
            .navigationTitle(supplier == nil ? "Nuevo proveedor" : "Editar proveedor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.foregroundStyle(Color.stockSubtle)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task {
                            guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { error = "El nombre es obligatorio."; return }
                            isLoading = true; defer { isLoading = false }
                            let inp = SupplierInput(name: name, contactName: contactName.isEmpty ? nil : contactName,
                                email: email.isEmpty ? nil : email, phone: phone.isEmpty ? nil : phone,
                                address: address.isEmpty ? nil : address, notes: notes.isEmpty ? nil : notes)
                            do { try await vm.save(id: supplier?.id, input: inp); dismiss() }
                            catch { self.error = error.localizedDescription }
                        }
                    }
                    .disabled(isLoading).foregroundStyle(Color.stockLight)
                }
            }
            .onAppear {
                name = supplier?.name ?? ""; contactName = supplier?.contactName ?? ""
                email = supplier?.email ?? ""; phone = supplier?.phone ?? ""
                address = supplier?.address ?? ""; notes = supplier?.notes ?? ""
            }
            .errorAlert(error: Binding(get: { error }, set: { error = $0 }))
        }
    }
}
