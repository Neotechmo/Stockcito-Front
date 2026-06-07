import SwiftUI

@Observable
private class ProductFormViewModel {
    var name = "";  var sku = "";       var description = ""
    var unitOfMeasure = "pieza"
    var minStock = "";  var currentStock = "";  var unitPrice = "";  var barcode = ""
    var selectedCategoryId: Int64?
    var selectedSupplierId: Int64?
    var categories: [Category] = []
    var suppliers: [Supplier] = []
    var isLoading = false
    var error: String?

    func populate(from p: Product) {
        name = p.name; sku = p.sku ?? ""; description = p.description ?? ""
        unitOfMeasure = p.unitOfMeasure
        minStock = (p.minStock ?? 0).stockFormatted
        currentStock = (p.currentStock ?? 0).stockFormatted
        unitPrice = p.unitPrice.map { String($0) } ?? ""
        barcode = p.barcode ?? ""
        selectedCategoryId = p.categoryId; selectedSupplierId = p.supplierId
    }

    func loadCatalogs() async {
        async let cats: [Category] = (try? APIClient.shared.get("v1/categories")) ?? []
        async let sups: [Supplier] = (try? APIClient.shared.get("v1/suppliers")) ?? []
        categories = await cats; suppliers = await sups
        if selectedCategoryId == nil { selectedCategoryId = categories.first?.id }
    }

    func save(productId: Int64?) async throws {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw APIError.serverError("El nombre es obligatorio.")
        }
        guard let catId = selectedCategoryId else {
            throw APIError.serverError("Selecciona una categoría.")
        }
        let input = ProductInput(
            categoryId: catId, supplierId: selectedSupplierId,
            name: name.trimmingCharacters(in: .whitespaces),
            sku: sku.isEmpty ? nil : sku,
            description: description.isEmpty ? nil : description,
            unitOfMeasure: unitOfMeasure.isEmpty ? "pieza" : unitOfMeasure,
            minStock: Double(minStock) ?? 0, currentStock: Double(currentStock) ?? 0,
            unitPrice: Double(unitPrice), barcode: barcode.isEmpty ? nil : barcode
        )
        if let id = productId {
            let _: Product = try await APIClient.shared.putJSON("v1/products/\(id)", body: input)
        } else {
            let _: Product = try await APIClient.shared.postJSON("v1/products", body: input)
        }
    }
}

struct ProductFormView: View {
    let product: Product?
    let onSave: () async -> Void

    @State private var vm = ProductFormViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Básico
                    FormSection(title: "Información básica") {
                        FormField(label: "Nombre *") {
                            TextField("Nombre del producto", text: $vm.name).stockField()
                        }
                        FormField(label: "SKU") {
                            TextField("Código SKU", text: $vm.sku)
                                .autocapitalization(.allCharacters).stockField()
                        }
                        FormField(label: "Código de barras") {
                            TextField("Código de barras", text: $vm.barcode).stockField()
                        }
                        FormField(label: "Descripción") {
                            TextField("Descripción opcional", text: $vm.description, axis: .vertical)
                                .lineLimit(2...3).stockField()
                        }
                    }

                    // Inventario
                    FormSection(title: "Inventario") {
                        FormField(label: "Unidad de medida") {
                            TextField("pieza, kg, litro…", text: $vm.unitOfMeasure).stockField()
                        }
                        HStack(spacing: 12) {
                            FormField(label: "Stock actual") {
                                TextField("0", text: $vm.currentStock)
                                    .keyboardType(.decimalPad).stockField()
                            }
                            FormField(label: "Stock mínimo") {
                                TextField("0", text: $vm.minStock)
                                    .keyboardType(.decimalPad).stockField()
                            }
                        }
                        FormField(label: "Precio unitario") {
                            TextField("0.00", text: $vm.unitPrice)
                                .keyboardType(.decimalPad).stockField()
                        }
                    }

                    // Categoría
                    FormSection(title: "Categoría *") {
                        if vm.categories.isEmpty {
                            Text("Sin categorías disponibles").foregroundStyle(Color.stockMuted)
                                .padding(14)
                        } else {
                            Picker("Categoría", selection: $vm.selectedCategoryId) {
                                ForEach(vm.categories) { cat in
                                    Text(cat.name).tag(Optional(cat.id))
                                        .foregroundStyle(Color.stockLight)
                                }
                            }
                            .tint(Color.stockLight)
                            .padding(14)
                            .background(Color.stockElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // Proveedor
                    FormSection(title: "Proveedor") {
                        Picker("Proveedor", selection: $vm.selectedSupplierId) {
                            Text("Sin proveedor").tag(Optional<Int64>.none)
                            ForEach(vm.suppliers) { sup in
                                Text(sup.name).tag(Optional(sup.id))
                                    .foregroundStyle(Color.stockLight)
                            }
                        }
                        .tint(Color.stockLight)
                        .padding(14)
                        .background(Color.stockElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.top, 16).padding(.bottom, 8)
            }
            .stockBackground()
            .navigationTitle(product == nil ? "Nuevo producto" : "Editar producto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.foregroundStyle(Color.stockSubtle)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task {
                            vm.isLoading = true
                            defer { vm.isLoading = false }
                            do {
                                try await vm.save(productId: product?.id)
                                await onSave(); dismiss()
                            } catch { vm.error = error.localizedDescription }
                        }
                    }
                    .disabled(vm.isLoading)
                    .foregroundStyle(Color.stockLight)
                }
            }
            .task { await vm.loadCatalogs(); if let p = product { vm.populate(from: p) } }
            .errorAlert(error: Binding(get: { vm.error }, set: { vm.error = $0 }))
        }
    }
}

// MARK: - Form helpers
struct FormSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.bold())
                .foregroundStyle(Color.stockMuted)
                .tracking(1.5)
                .padding(.horizontal, 24)
            VStack(spacing: 10) { content() }
                .padding(.horizontal, 20)
        }
    }
}

struct FormField<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(Color.stockSubtle)
                .tracking(0.5)
            content()
        }
    }
}
