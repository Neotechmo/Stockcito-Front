import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // ── Tarjeta de usuario ──────────────────────────────
                    if let user = session.currentUser {
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.stockElevated)
                                    .frame(width: 72, height: 72)
                                Text(String(user.name.prefix(1)).uppercased())
                                    .font(.largeTitle.bold())
                                    .foregroundStyle(Color.stockLight)
                            }
                            VStack(spacing: 4) {
                                Text(user.name)
                                    .font(.title3.bold())
                                    .foregroundStyle(Color.stockLight)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.stockSubtle)
                            }
                            StatusBadge(text: user.role ?? "OPERADOR", color: Color.stockSubtle)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(Color.stockCard)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal)
                    }

                    // ── Cuenta ──────────────────────────────────────────
                    VStack(spacing: 10) {
                        // Editar perfil
                        Button { showEdit = true } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.stockElevated)
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "pencil")
                                        .font(.caption.bold())
                                        .foregroundStyle(Color.stockSubtle)
                                }
                                Text("Editar perfil")
                                    .font(.body)
                                    .foregroundStyle(Color.stockLight)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(Color.stockMuted)
                            }
                            .padding(16)
                            .background(Color.stockCard)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .padding(.horizontal)

                        // Cerrar sesión
                        Button(role: .destructive) {
                            session.logout()
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.red.opacity(0.15))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.caption.bold())
                                        .foregroundStyle(.red)
                                }
                                Text("Cerrar sesión")
                                    .font(.body)
                                    .foregroundStyle(.red)
                                Spacer()
                            }
                            .padding(16)
                            .background(Color.stockCard)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 8)
            }
            .stockBackground()
            .navigationTitle("Perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(Color.stockSubtle)
                }
            }
            .sheet(isPresented: $showEdit) {
                if let user = session.currentUser {
                    EditProfileSheet(user: user, session: session)
                }
            }
        }
    }
}

// MARK: - Formulario de edición

private struct EditProfileSheet: View {
    let user: User
    let session: SessionStore

    @State private var name: String
    @State private var email: String
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var isLoading = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    init(user: User, session: SessionStore) {
        self.user = user
        self.session = session
        _name  = State(initialValue: user.name)
        _email = State(initialValue: user.email)
    }

    private var passwordsMatch: Bool {
        password.isEmpty || password == confirmPassword
    }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
        && email.contains("@")
        && passwordsMatch
        && (password.isEmpty || password.count >= 6)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Avatar grande
                    ZStack {
                        Circle()
                            .fill(Color.stockElevated)
                            .frame(width: 72, height: 72)
                        Text(String(name.prefix(1)).uppercased())
                            .font(.largeTitle.bold())
                            .foregroundStyle(Color.stockLight)
                    }
                    .padding(.top, 4)

                    // Datos básicos
                    FormSection(title: "Información personal") {
                        FormField(label: "Nombre *") {
                            TextField("Tu nombre completo", text: $name)
                                .textContentType(.name)
                                .stockField()
                        }
                        FormField(label: "Email *") {
                            TextField("correo@ejemplo.com", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .textContentType(.emailAddress)
                                .stockField()
                        }
                    }

                    // Cambio de contraseña (opcional)
                    FormSection(title: "Cambiar contraseña") {
                        FormField(label: "Nueva contraseña") {
                            HStack {
                                Group {
                                    if showPassword {
                                        TextField("Mínimo 6 caracteres", text: $password)
                                    } else {
                                        SecureField("Mínimo 6 caracteres", text: $password)
                                    }
                                }
                                .textContentType(.newPassword)
                                .autocapitalization(.none)
                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundStyle(Color.stockMuted)
                                }
                            }
                            .stockField()
                        }

                        if !password.isEmpty {
                            FormField(label: "Confirmar contraseña") {
                                SecureField("Repite la contraseña", text: $confirmPassword)
                                    .textContentType(.newPassword)
                                    .autocapitalization(.none)
                                    .stockField()
                                    .overlay(alignment: .trailing) {
                                        if !confirmPassword.isEmpty {
                                            Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                                                .foregroundStyle(passwordsMatch ? .green : .red)
                                                .padding(.trailing, 14)
                                        }
                                    }
                            }
                        }

                        Text("Deja vacío si no quieres cambiar la contraseña.")
                            .font(.caption)
                            .foregroundStyle(Color.stockMuted)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.top, 8).padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.immediately)
            .stockBackground()
            .navigationTitle("Editar perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Color.stockSubtle)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isLoading {
                            ProgressView().tint(Color.stockLight).scaleEffect(0.8)
                        } else {
                            Text("Guardar")
                        }
                    }
                    .disabled(!canSave || isLoading)
                    .foregroundStyle(canSave ? Color.stockLight : Color.stockMuted)
                }
            }
            .errorAlert(error: Binding(get: { error }, set: { error = $0 }))
        }
    }

    private func save() async {
        guard canSave else { return }
        isLoading = true; defer { isLoading = false }

        let input = UserUpdateInput(
            name:     name.trimmingCharacters(in: .whitespaces),
            email:    email.trimmingCharacters(in: .whitespaces).lowercased(),
            password: password.isEmpty ? nil : password
        )
        do {
            let updated: User = try await APIClient.shared.putJSON("v1/users/\(user.id)", body: input)
            session.updateCurrentUser(updated)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
