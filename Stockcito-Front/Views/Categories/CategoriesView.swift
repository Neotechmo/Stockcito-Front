import SwiftUI

@Observable
private class CategoriesViewModel {
    var categories: [Category] = []
    var isLoading = false
    var error: String?

    func load() async {
        isLoading = true; defer { isLoading = false }
        do { categories = try await APIClient.shared.get("v1/categories") }
        catch { self.error = error.localizedDescription }
    }
    func delete(_ c: Category) async {
        do {
            try await APIClient.shared.delete("v1/categories/\(c.id)")
            categories.removeAll { $0.id == c.id }
        } catch { self.error = error.localizedDescription }
    }
    func save(id: Int64?, name: String, description: String?) async throws {
        let inp = CategoryInput(name: name, description: description?.isEmpty == true ? nil : description)
        if let id { let _: Category = try await APIClient.shared.putJSON("v1/categories/\(id)", body: inp) }
        else       { let _: Category = try await APIClient.shared.postJSON("v1/categories", body: inp) }
        await load()
    }
}

struct CategoriesView: View {
    @State private var vm = CategoriesViewModel()
    @State private var showForm = false
    @State private var editItem: Category?

    var body: some View {
        NavigationStack {
            List {
                ForEach(vm.categories) { cat in
                    Button { editItem = cat } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.stockElevated).frame(width: 40, height: 40)
                                Image(systemName: "tag.fill").foregroundStyle(Color.stockSubtle)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(cat.name).font(.body.bold()).foregroundStyle(Color.stockLight)
                                if let d = cat.description {
                                    Text(d).font(.caption).foregroundStyle(Color.stockSubtle).lineLimit(1)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.stockMuted)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.stockCard)
                    .listRowSeparatorTint(Color.stockElevated)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await vm.delete(cat) }
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                        Button { editItem = cat } label: {
                            Label("Editar", systemImage: "pencil")
                        }
                        .tint(.indigo)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .stockBackground()
            .navigationTitle("Categorías")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showForm = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.stockSubtle)
                    }
                }
            }
            .refreshable { await vm.load() }
            .overlay { if vm.isLoading && vm.categories.isEmpty { ProgressView().tint(Color.stockSubtle) } }
            .task { await vm.load() }
            .sheet(isPresented: $showForm) { CategoryFormSheet(category: nil, vm: vm) }
            .sheet(item: $editItem) { cat in CategoryFormSheet(category: cat, vm: vm) }
            .errorAlert(error: Binding(get: { vm.error }, set: { vm.error = $0 }))
        }
    }
}

private struct CategoryFormSheet: View {
    let category: Category?
    let vm: CategoriesViewModel
    @State private var name = ""; @State private var description = ""
    @State private var isLoading = false; @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    FormSection(title: "Datos") {
                        FormField(label: "Nombre *") { TextField("Nombre de categoría", text: $name).stockField() }
                        FormField(label: "Descripción") {
                            TextField("Descripción opcional", text: $description, axis: .vertical)
                                .lineLimit(2...4).stockField()
                        }
                    }
                }
                .padding(.top, 16)
            }
            .stockBackground()
            .navigationTitle(category == nil ? "Nueva categoría" : "Editar categoría")
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
                            do { try await vm.save(id: category?.id, name: name, description: description); dismiss() }
                            catch { self.error = error.localizedDescription }
                        }
                    }
                    .disabled(isLoading).foregroundStyle(Color.stockLight)
                }
            }
            .onAppear { name = category?.name ?? ""; description = category?.description ?? "" }
            .errorAlert(error: Binding(get: { error }, set: { error = $0 }))
            .doneKeyboardToolbar()
        }
    }
}

#Preview { CategoriesView() }
