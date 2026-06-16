import SwiftUI

@Observable
private class RegisterViewModel {
    var name = ""
    var email = ""
    var password = ""
    var isLoading = false
    var error: String?

    func register(session: SessionStore) async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            error = "El nombre es obligatorio."; return
        }
        guard email.contains("@") else { error = "Email inválido."; return }
        guard password.count >= 6 else {
            error = "La contraseña debe tener al menos 6 caracteres."; return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let res: AuthResponse = try await APIClient.shared.postJSON(
                "v1/auth/register",
                body: RegisterInput(name: name, email: email, password: password)
            )
            session.login(token: res.token, user: res.user)
        } catch { self.error = error.localizedDescription }
    }
}

struct RegisterView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var vm = RegisterViewModel()

    var body: some View {
        ZStack {
            Color.stockBase.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(Color.stockSubtle)
                            .padding(.top, 32)
                        Text("Nueva cuenta")
                            .font(.title2.bold())
                            .foregroundStyle(Color.stockLight)
                        Text("Tu rol será Operador")
                            .font(.caption)
                            .foregroundStyle(Color.stockMuted)
                    }

                    // Campos
                    VStack(spacing: 16) {
                        fieldBlock(label: "Nombre completo", icon: "person") {
                            TextField("Tu nombre", text: $vm.name)
                                .textContentType(.name)
                                .stockField()
                        }
                        fieldBlock(label: "Email", icon: "envelope") {
                            TextField("correo@ejemplo.com", text: $vm.email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .textContentType(.emailAddress)
                                .stockField()
                        }
                        fieldBlock(label: "Contraseña", icon: "lock") {
                            SecureField("Mín. 6 caracteres", text: $vm.password)
                                .textContentType(.newPassword)
                                .stockField()
                        }

                        StockButton(title: "Crear cuenta", isLoading: vm.isLoading) {
                            Task { await vm.register(session: session) }
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .navigationTitle("Registro")
        .navigationBarTitleDisplayMode(.inline)
        .errorAlert(error: Binding(get: { vm.error }, set: { vm.error = $0 }))
    }

    private func fieldBlock<F: View>(label: String, icon: String, @ViewBuilder field: () -> F) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: icon)
                .font(.caption.bold())
                .foregroundStyle(Color.stockSubtle)
                .textCase(.uppercase)
                .tracking(1)
            field()
        }
    }
}
