import SwiftUI
import Combine

class SessionStore: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoggedIn = false

    init() {
        if let data = UserDefaults.standard.data(forKey: "saved_user"),
           let user = try? JSONDecoder().decode(User.self, from: data),
           APIClient.shared.isAuthenticated {
            currentUser = user
            isLoggedIn = true
        }
    }

    func login(token: String, user: User) {
        APIClient.shared.token = token
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: "saved_user")
        }
        withAnimation { isLoggedIn = true }
        currentUser = user
    }

    func updateCurrentUser(_ user: User) {
        currentUser = user
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: "saved_user")
        }
    }

    func logout() {
        APIClient.shared.clearSession()
        withAnimation { isLoggedIn = false }
        currentUser = nil
    }
}
