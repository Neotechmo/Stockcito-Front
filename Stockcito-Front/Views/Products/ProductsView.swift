import SwiftUI

@Observable
class ProductsViewModel {
    var products: [Product] = []
    var categories: [Category] = []
    var isLoading = false
    var error: String?
    var searchText = ""
    var selectedCategoryId: Int64? = nil   // nil = "Todos"

    var filtered: [Product] {
        products.filter { product in
            let matchesCategory = selectedCategoryId == nil || product.categoryId == selectedCategoryId
            let matchesSearch   = searchText.isEmpty
                || product.name.localizedCaseInsensitiveContains(searchText)
                || (product.sku?.localizedCaseInsensitiveContains(searchText) ?? false)
                || (product.barcode?.localizedCaseInsensitiveContains(searchText) ?? false)
            return matchesCategory && matchesSearch
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do { products = try await APIClient.shared.get("v1/products") }
        catch { self.error = error.localizedDescription }
    }

    func loadCategories() async {
        categories = (try? await APIClient.shared.get("v1/categories")) ?? []
    }

    func delete(_ product: Product) async {
        do {
            try await APIClient.shared.delete("v1/products/\(product.id)")
            products.removeAll { $0.id == product.id }
        } catch { self.error = error.localizedDescription }
    }
}

struct ProductsView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var vm = ProductsViewModel()
    @State private var showingForm = false
    @State private var editProduct: Product?
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Buscador
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Color.stockMuted)
                        TextField("Nombre, SKU o código…", text: $vm.searchText)
                            .foregroundStyle(Color.stockLight)
                            .tint(Color.stockLight)
                    }
                    .padding(12)
                    .background(Color.stockCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)

                    // Filtros por categoría
                    if !vm.categories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                // Chip "Todos"
                                CategoryChip(
                                    label: "Todos",
                                    isSelected: vm.selectedCategoryId == nil
                                ) {
                                    withAnimation(.spring(response: 0.3)) {
                                        vm.selectedCategoryId = nil
                                    }
                                }
                                ForEach(vm.categories) { cat in
                                    CategoryChip(
                                        label: cat.name,
                                        isSelected: vm.selectedCategoryId == cat.id
                                    ) {
                                        withAnimation(.spring(response: 0.3)) {
                                            vm.selectedCategoryId = (vm.selectedCategoryId == cat.id) ? nil : cat.id
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Botón agregar
                    Button { showingForm = true } label: {
                        Label("Agregar producto", systemImage: "plus")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.stockElevated)
                            .foregroundStyle(Color.stockSubtle)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)

                    if vm.isLoading && vm.products.isEmpty {
                        ProgressView().tint(Color.stockSubtle).padding(.top, 60)
                    } else if vm.filtered.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "cube.box")
                                .font(.system(size: 40)).foregroundStyle(Color.stockMuted)
                            Text(vm.searchText.isEmpty && vm.selectedCategoryId != nil
                                 ? "Sin productos en esta categoría"
                                 : "Sin resultados")
                                .foregroundStyle(Color.stockSubtle)
                        }
                        .padding(.top, 60)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(vm.filtered) { product in
                                NavigationLink(destination: ProductDetailView(product: product, vm: vm)) {
                                    ProductCard(product: product)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button { editProduct = product } label: {
                                        Label("Editar", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        Task { await vm.delete(product) }
                                    } label: {
                                        Label("Eliminar", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.immediately)
            .stockBackground()
            .navigationTitle("Productos")
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
            .task {
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { await vm.load() }
                    group.addTask { await vm.loadCategories() }
                }
            }
            .sheet(isPresented: $showingForm) {
                ProductFormView(product: nil) { await vm.load() }
            }
            .sheet(item: $editProduct) { product in
                ProductFormView(product: product) { await vm.load() }
            }
            .sheet(isPresented: $showProfile) {
                ProfileView().environmentObject(session)
            }
            .errorAlert(error: Binding(get: { vm.error }, set: { vm.error = $0 }))
            .floatingTabBarPadding()
        }
    }
}

// MARK: - Category chip

private struct CategoryChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.subheadline.bold())
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(isSelected ? Color.stockMuted : Color.stockCard)
                .foregroundStyle(isSelected ? Color.stockLight : Color.stockSubtle)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Product card
struct ProductCard: View {
    let product: Product

    private var stockColor: Color {
        (product.currentStock ?? 0) <= (product.minStock ?? 0) ? .orange : .green
    }

    var body: some View {
        HStack(spacing: 14) {
            // Ícono con color de categoría
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.stockElevated)
                    .frame(width: 44, height: 44)
                Image(systemName: "cube.fill")
                    .foregroundStyle(Color.stockSubtle)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.body.bold())
                    .foregroundStyle(Color.stockLight)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let cat = product.categoryName {
                        Text(cat)
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.stockElevated)
                            .foregroundStyle(Color.stockSubtle)
                            .clipShape(Capsule())
                    }
                    if let sku = product.sku {
                        Text("SKU: \(sku)")
                            .font(.caption2)
                            .foregroundStyle(Color.stockMuted)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\((product.currentStock ?? 0).stockFormatted)")
                    .font(.body.bold().monospacedDigit())
                    .foregroundStyle(stockColor)
                Text(product.unitOfMeasure)
                    .font(.caption2)
                    .foregroundStyle(Color.stockMuted)
                if let price = product.unitPrice {
                    Text(price.priceFormatted)
                        .font(.caption2)
                        .foregroundStyle(Color.stockSubtle)
                }
            }
        }
        .padding(14)
        .background(Color.stockCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Product detail
struct ProductDetailView: View {
    let product: Product
    let vm: ProductsViewModel
    @State private var showEdit = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header card
                VStack(spacing: 8) {
                    ZStack {
                        Circle().fill(Color.stockElevated).frame(width: 64, height: 64)
                        Image(systemName: "cube.fill")
                            .font(.title2)
                            .foregroundStyle(Color.stockSubtle)
                    }
                    Text(product.name)
                        .font(.title3.bold())
                        .foregroundStyle(Color.stockLight)
                    HStack(spacing: 8) {
                        if let cat = product.categoryName {
                            StatusBadge(text: cat, color: Color.stockSubtle)
                        }
                        StatusBadge(
                            text: (product.currentStock ?? 0) <= (product.minStock ?? 0) ? "Stock bajo" : "OK",
                            color: (product.currentStock ?? 0) <= (product.minStock ?? 0) ? .orange : .green
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                .stockCard(padding: 20)
                .padding(.horizontal)

                // Datos
                InfoSection(title: "Inventario") {
                    InfoRow(label: "Stock actual",   value: "\((product.currentStock ?? 0).stockFormatted) \(product.unitOfMeasure)")
                    InfoRow(label: "Stock mínimo",   value: "\((product.minStock ?? 0).stockFormatted) \(product.unitOfMeasure)")
                    if let price = product.unitPrice { InfoRow(label: "Precio",   value: price.priceFormatted) }
                }

                InfoSection(title: "Identificación") {
                    if let sku = product.sku     { InfoRow(label: "SKU",     value: sku) }
                    if let bc  = product.barcode { InfoRow(label: "Cód. barras", value: bc) }
                    if let desc = product.description { InfoRow(label: "Descripción", value: desc) }
                }

                InfoSection(title: "Relaciones") {
                    InfoRow(label: "Categoría", value: product.categoryName ?? "-")
                    InfoRow(label: "Proveedor", value: product.supplierName ?? "Sin proveedor")
                }
            }
            .padding(.top, 16).padding(.bottom, 8)
        }
        .stockBackground()
        .navigationTitle(product.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Editar") { showEdit = true }
                    .foregroundStyle(Color.stockSubtle)
            }
        }
        .sheet(isPresented: $showEdit) {
            ProductFormView(product: product) { await vm.load() }
        }
    }
}

// MARK: - Helpers
struct InfoSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.caption.bold())
                .foregroundStyle(Color.stockMuted)
                .tracking(1.5)
                .padding(.horizontal).padding(.bottom, 8)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.stockCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(Color.stockSubtle)
            Spacer()
            Text(value)
                .foregroundStyle(Color.stockLight)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.vertical, 5)
    }
}
