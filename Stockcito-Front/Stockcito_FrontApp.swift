import SwiftUI

@main
struct Stockcito_FrontApp: App {
    init() {
        AppTheme.apply()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
