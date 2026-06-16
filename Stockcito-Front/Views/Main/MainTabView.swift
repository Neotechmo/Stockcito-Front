import SwiftUI

// MARK: - Tab definition
private struct TabItem {
    let icon: String
    let selectedIcon: String
    let label: String
}

private let tabItems: [TabItem] = [
    TabItem(icon: "chart.bar",                  selectedIcon: "chart.bar.fill",                  label: "Inicio"),
    TabItem(icon: "cube.box",                   selectedIcon: "cube.box.fill",                   label: "Productos"),
    TabItem(icon: "arrow.up.arrow.down.circle", selectedIcon: "arrow.up.arrow.down.circle.fill", label: "Movimientos"),
    TabItem(icon: "cart",                       selectedIcon: "cart.fill",                       label: "Solicitudes"),
    TabItem(icon: "building.2",                 selectedIcon: "building.2.fill",                 label: "Proveedores"),
    TabItem(icon: "doc.text.viewfinder",        selectedIcon: "doc.text.viewfinder",             label: "Importar"),
    TabItem(icon: "tag",                        selectedIcon: "tag.fill",                        label: "Categorías"),
]

// MARK: - MainTabView
struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // Contenido activo
            Group {
                switch selectedTab {
                case 0: DashboardView()
                case 1: ProductsView()
                case 2: MovementsView()
                case 3: PurchaseRequestsView()
                case 4: SuppliersView()
                case 5: ImportsView()
                default: CategoriesView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Espacio para que el contenido no quede detrás del tab bar
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) }

            // Tab bar flotante
            FloatingTabBar(selectedTab: $selectedTab)
        }
        .background(Color.stockBase)
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - FloatingTabBar
private struct FloatingTabBar: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabItems.indices, id: \.self) { index in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: selectedTab == index
                              ? tabItems[index].selectedIcon
                              : tabItems[index].icon)
                            .font(.system(size: 17, weight: selectedTab == index ? .bold : .regular))
                            .foregroundStyle(selectedTab == index ? Color.stockLight : Color.stockMuted)
                            .scaleEffect(selectedTab == index ? 1.1 : 1.0)

                        // Dot indicator
                        Circle()
                            .fill(Color.stockSubtle)
                            .frame(width: 4, height: 4)
                            .opacity(selectedTab == index ? 1 : 0)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.stockCard)
                .shadow(color: Color.black.opacity(0.5), radius: 24, x: 0, y: -6)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
    }
}
