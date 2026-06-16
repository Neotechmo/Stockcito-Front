import SwiftUI

struct ContentView: View {
    @StateObject private var session = SessionStore()

    var body: some View {
        Group {
            if session.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .environmentObject(session)
        .animation(.easeInOut(duration: 0.35), value: session.isLoggedIn)
        .doneKeyboardToolbar()
    }
}

#Preview {
    ContentView()
}
