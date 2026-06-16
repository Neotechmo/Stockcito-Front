import SwiftUI

@Observable
private class LoginViewModel {
    var email = ""
    var password = ""
    var isLoading = false
    var error: String?

    func login(session: SessionStore) async {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty,
              !password.isEmpty else {
            error = "Email y contraseña son obligatorios."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let res: AuthResponse = try await APIClient.shared.postJSON(
                "v1/auth/login",
                body: LoginInput(email: email, password: password)
            )
            session.login(token: res.token, user: res.user)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct LoginView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var vm = LoginViewModel()
    @State private var goToRegister = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.stockBase.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Header con logo
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.stockElevated, Color.stockMuted],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 88, height: 88)
                                    .shadow(color: Color.stockMuted.opacity(0.4), radius: 20)
                                Image(systemName: "cube.box.fill")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundStyle(Color.stockLight)
                            }
                            Text("Stockcito")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.stockLight)
                            Text("Control de inventario")
                                .font(.subheadline)
                                .foregroundStyle(Color.stockSubtle)
                        }
                        .padding(.top, 72)
                        .padding(.bottom, 48)

                        // Formulario
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Email", systemImage: "envelope")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.stockSubtle)
                                    .textCase(.uppercase)
                                    .tracking(1)
                                TextField("correo@ejemplo.com", text: $vm.email)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .textContentType(.emailAddress)
                                    .stockField()
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Label("Contraseña", systemImage: "lock")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.stockSubtle)
                                    .textCase(.uppercase)
                                    .tracking(1)
                                SecureField("••••••••", text: $vm.password)
                                    .textContentType(.password)
                                    .stockField()
                            }

                            StockButton(title: "Iniciar sesión", isLoading: vm.isLoading) {
                                Task { await vm.login(session: session) }
                            }
                            .padding(.top, 8)

                            Button {
                                goToRegister = true
                            } label: {
                                HStack(spacing: 4) {
                                    Text("¿No tienes cuenta?")
                                        .foregroundStyle(Color.stockSubtle)
                                    Text("Regístrate")
                                        .foregroundStyle(Color.stockLight)
                                        .fontWeight(.semibold)
                                }
                                .font(.subheadline)
                            }
                            .padding(.top, 4)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationDestination(isPresented: $goToRegister) {
                RegisterView()
            }
        }
        .errorAlert(error: Binding(get: { vm.error }, set: { vm.error = $0 }))
    }
}
