import SwiftUI

// MARK: - Paleta de colores
extension Color {
    /// #06141B — fondo principal profundo
    static let stockBase    = Color(hex: "06141B")
    /// #11212D — superficie de tarjetas
    static let stockCard    = Color(hex: "11212D")
    /// #253745 — superficies elevadas / inputs
    static let stockElevated = Color(hex: "253745")
    /// #4A5C6A — elementos inactivos / bordes
    static let stockMuted   = Color(hex: "4A5C6A")
    /// #9BA8AB — texto secundario / íconos
    static let stockSubtle  = Color(hex: "9BA8AB")
    /// #CCD0CF — texto primario / elemento activo
    static let stockLight   = Color(hex: "CCD0CF")

    init(hex: String) {
        var h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        self.init(
            red:   Double((int >> 16) & 0xFF) / 255,
            green: Double((int >>  8) & 0xFF) / 255,
            blue:  Double( int        & 0xFF) / 255
        )
    }
}

// MARK: - UIKit appearance (llámalo en App.init)
enum AppTheme {
    static func apply() {
        // Navigation bar
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(Color.stockBase)
        nav.titleTextAttributes           = [.foregroundColor: UIColor(Color.stockLight)]
        nav.largeTitleTextAttributes      = [.foregroundColor: UIColor(Color.stockLight)]
        nav.buttonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(Color.stockSubtle)]
        UINavigationBar.appearance().standardAppearance  = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance    = nav
        UINavigationBar.appearance().tintColor = UIColor(Color.stockSubtle)

        // Sheet / form background
        UITableView.appearance().backgroundColor = UIColor(Color.stockBase)
        UITableViewCell.appearance().backgroundColor = UIColor(Color.stockCard)
    }
}

// MARK: - Modificadores reutilizables
struct StockCard: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.stockCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

extension View {
    func stockCard(padding: CGFloat = 16) -> some View { modifier(StockCard(padding: padding)) }
    func stockBackground() -> some View { background(Color.stockBase.ignoresSafeArea()) }

    /// Añade espacio en la parte inferior para que el contenido no quede oculto detrás del tab bar flotante.
    func floatingTabBarPadding() -> some View {
        self.safeAreaInset(edge: .bottom) { Color.clear.frame(height: 50) }
    }

    /// Campo de texto oscuro con la paleta
    func stockField() -> some View {
        self
            .padding(14)
            .background(Color.stockElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(Color.stockLight)
    }
}

// MARK: - Botón primario
struct StockButton: View {
    let title: String
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView().tint(Color.stockLight)
                } else {
                    Text(title).font(.body.bold())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Color.stockElevated, Color.stockMuted],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .foregroundStyle(Color.stockLight)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isLoading)
    }
}

// MARK: - Badge de estado
struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
