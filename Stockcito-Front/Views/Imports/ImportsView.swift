import SwiftUI
import PhotosUI
import Vision

@Observable
private class ImportsViewModel {
    var jobs: [ImportJob] = []
    var isLoading = false
    var error: String?
    var statusFilter = "ALL"

    var filtered: [ImportJob] {
        statusFilter == "ALL" ? jobs : jobs.filter { $0.status == statusFilter }
    }

    func load() async {
        isLoading = true; defer { isLoading = false }
        do { jobs = try await APIClient.shared.get("v1/imports") }
        catch { self.error = error.localizedDescription }
    }
    func confirm(id: Int64) async {
        do {
            let updated: ImportJob = try await APIClient.shared.post("v1/imports/\(id)/confirm")
            if let idx = jobs.firstIndex(where: { $0.id == id }) { jobs[idx] = updated }
        } catch { self.error = error.localizedDescription }
    }
    func cancel(id: Int64) async {
        do {
            let updated: ImportJob = try await APIClient.shared.post("v1/imports/\(id)/cancel")
            if let idx = jobs.firstIndex(where: { $0.id == id }) { jobs[idx] = updated }
        } catch { self.error = error.localizedDescription }
    }
}

// MARK: - Vista principal

struct ImportsView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var vm = ImportsViewModel()
    @State private var showForm = false
    @State private var selectedJob: ImportJob?
    @State private var showProfile = false

    private let filters: [(label: String, value: String)] = [
        ("Todos",       "ALL"),
        ("Vista previa","PREVIEW"),
        ("Confirmado",  "CONFIRMED"),
        ("Cancelado",   "CANCELLED"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {

                    // ── Filtros ───────────────────────────────────────
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filters, id: \.value) { filter in
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        vm.statusFilter = filter.value
                                    }
                                } label: {
                                    Text(filter.label)
                                        .font(.subheadline.bold())
                                        .padding(.horizontal, 16).padding(.vertical, 8)
                                        .background(vm.statusFilter == filter.value
                                                    ? Color.stockMuted : Color.stockCard)
                                        .foregroundStyle(vm.statusFilter == filter.value
                                                         ? Color.stockLight : Color.stockSubtle)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // ── Botón escanear ────────────────────────────────
                    Button { showForm = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text.viewfinder")
                            Text("Escanear / importar ticket")
                                .font(.subheadline.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.stockElevated)
                        .foregroundStyle(Color.stockSubtle)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)

                    // ── Lista ─────────────────────────────────────────
                    if vm.isLoading && vm.jobs.isEmpty {
                        ProgressView().tint(Color.stockSubtle).padding(.top, 60)
                    } else if vm.filtered.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 40)).foregroundStyle(Color.stockMuted)
                            Text(vm.statusFilter == "ALL"
                                 ? "Sin importaciones" : "Sin importaciones en este estado")
                                .foregroundStyle(Color.stockSubtle)
                        }
                        .padding(.top, 60)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(vm.filtered) { job in
                                ImportJobCard(job: job)
                                    .onTapGesture { selectedJob = job }
                                    .contextMenu {
                                        if job.status == "PREVIEW" {
                                            Button { Task { await vm.confirm(id: job.id) } }
                                                label: { Label("Confirmar", systemImage: "checkmark.circle") }
                                            Button { Task { await vm.cancel(id: job.id) } }
                                                label: { Label("Cancelar", systemImage: "xmark.circle") }
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 16).padding(.bottom, 8)
            }
            .stockBackground()
            .navigationTitle("Importaciones")
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
            .task { await vm.load() }
            .sheet(isPresented: $showForm) {
                ImportPreviewSheet(currentUserId: session.currentUser?.id ?? 0) { await vm.load() }
            }
            .sheet(item: $selectedJob) { job in
                ImportJobDetailSheet(job: job, vm: vm)
            }
            .sheet(isPresented: $showProfile) {
                ProfileView().environmentObject(session)
            }
            .errorAlert(error: Binding(get: { vm.error }, set: { vm.error = $0 }))
        }
    }
}

// MARK: - Card de importación

private struct ImportJobCard: View {
    let job: ImportJob

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(job.status.importStatusColor.opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: "doc.text.viewfinder")
                    .foregroundStyle(job.status.importStatusColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(job.sourceFilename ?? "Importación #\(job.id)")
                    .font(.body.bold()).foregroundStyle(Color.stockLight).lineLimit(1)
                HStack(spacing: 6) {
                    Text(job.sourceType).font(.caption2).foregroundStyle(Color.stockMuted)
                    if let at = job.createdAt {
                        Text("·").foregroundStyle(Color.stockMuted)
                        Text(at.readableDate).font(.caption2).foregroundStyle(Color.stockMuted)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                StatusBadge(text: job.status.importStatusLabel, color: job.status.importStatusColor)
                if let items = job.items {
                    Text("\(items.count) ítems").font(.caption2).foregroundStyle(Color.stockMuted)
                }
            }
        }
        .padding(14).background(Color.stockCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Sheet nueva importación

private struct ImportPreviewSheet: View {
    let currentUserId: Int64
    let onSave: () async -> Void

    @State private var photosItem: PhotosPickerItem?
    @State private var ticketImage: UIImage?
    @State private var isOCRRunning = false
    @State private var rawText = ""
    @State private var sourceFilename = ""
    @State private var notes = ""
    @State private var isLoading = false
    @State private var error: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // ── Zona de foto ──────────────────────────────────
                    if let image = ticketImage {

                        // Previsualización
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .frame(maxHeight: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .padding(.horizontal)

                            PhotosPicker(selection: $photosItem,
                                         matching: .images,
                                         photoLibrary: .shared()) {
                                Label("Cambiar foto", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                            }
                            .padding(.trailing, 24).padding(.top, 8)
                        }

                        // Estado del OCR
                        if isOCRRunning {
                            HStack(spacing: 10) {
                                ProgressView().tint(.purple)
                                Text("La IA está leyendo el ticket…")
                                    .font(.subheadline).foregroundStyle(Color.stockSubtle)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(Color.purple.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal)
                        } else if !rawText.isEmpty {
                            // Confirmación de éxito
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Texto extraído correctamente")
                                        .font(.subheadline.bold()).foregroundStyle(Color.stockLight)
                                    Text("\(rawText.components(separatedBy: .newlines).filter { !$0.isEmpty }.count) líneas detectadas")
                                        .font(.caption).foregroundStyle(Color.stockSubtle)
                                }
                                Spacer()
                            }
                            .padding(14)
                            .background(Color.green.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal)
                        }

                    } else {
                        // ── Estado inicial: sin foto ──────────────────
                        PhotosPicker(selection: $photosItem,
                                     matching: .images,
                                     photoLibrary: .shared()) {
                            VStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.purple.opacity(0.12))
                                        .frame(width: 80, height: 80)
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 34))
                                        .foregroundStyle(.purple)
                                }
                                VStack(spacing: 6) {
                                    Text("Subir foto del ticket")
                                        .font(.headline)
                                        .foregroundStyle(Color.stockLight)
                                    Text("La IA extrae los productos y cantidades\nautomáticamente")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.stockSubtle)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 44)
                            .background(Color.stockCard)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(Color.purple.opacity(0.3),
                                                  style: StrokeStyle(lineWidth: 1.5, dash: [7]))
                            )
                        }
                        .padding(.horizontal)
                    }

                    // ── Nombre del ticket (opcional) ──────────────────
                    if ticketImage != nil {
                        FormSection(title: "Identificador (opcional)") {
                            FormField(label: "Nombre del ticket") {
                                TextField("ticket_ferreteria_01", text: $sourceFilename).stockField()
                            }
                        }

                        FormSection(title: "Notas") {
                            FormField(label: "Observaciones adicionales") {
                                TextField("Opcional", text: $notes, axis: .vertical)
                                    .lineLimit(2...3).stockField()
                            }
                        }
                    }
                }
                .padding(.top, 24).padding(.bottom, 8)
            }
            .stockBackground()
            .navigationTitle("Nuevo escaneo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.foregroundStyle(Color.stockSubtle)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isLoading {
                            ProgressView().tint(Color.stockLight).scaleEffect(0.8)
                        } else {
                            Text("Procesar")
                        }
                    }
                    .disabled(isLoading || isOCRRunning || ticketImage == nil || rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .foregroundStyle(Color.stockLight)
                }
            }
            // Reaccionar cuando el usuario elige una foto
            .onChange(of: photosItem) { _, newItem in
                guard let newItem else { return }
                Task { await loadAndOCR(item: newItem) }
            }
            .errorAlert(error: Binding(get: { error }, set: { error = $0 }))
        }
    }

    // MARK: Cargar imagen + OCR

    private func loadAndOCR(item: PhotosPickerItem) async {
        isOCRRunning = true
        defer { isOCRRunning = false }

        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else {
            error = "No se pudo cargar la imagen."
            return
        }

        ticketImage = uiImage

        // Si no tiene nombre aún, usar timestamp
        if sourceFilename.isEmpty {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyyMMdd_HHmmss"
            sourceFilename = "ticket_\(fmt.string(from: Date()))"
        }

        // OCR con Vision
        let extracted = await recognizeText(in: uiImage)
        if !extracted.isEmpty {
            rawText = extracted
        } else {
            error = "No se encontró texto en la imagen. Puedes escribirlo manualmente."
        }
    }

    private func recognizeText(in image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { req, _ in
                let lines = (req.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string } ?? []
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel       = .accurate
            request.recognitionLanguages   = ["es-MX", "es", "en"]
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    // MARK: Enviar al backend

    private func submit() async {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            error = "El contenido del ticket no puede estar vacío."
            return
        }

        isLoading = true; defer { isLoading = false }

        let input = ImportJobInput(
            userId:         currentUserId,
            sourceType:     "IMAGE",
            sourceFilename: sourceFilename.isEmpty ? nil : sourceFilename,
            rawText:        text,
            aiModel:        nil,
            notes:          notes.isEmpty ? nil : notes
        )
        do {
            let _: ImportJob = try await APIClient.shared.postJSON("v1/imports/preview", body: input)
            await onSave()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Sheet detalle de importación

private struct ImportJobDetailSheet: View {
    let job: ImportJob
    let vm: ImportsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    VStack(spacing: 8) {
                        ZStack {
                            Circle().fill(job.status.importStatusColor.opacity(0.15)).frame(width: 64, height: 64)
                            Image(systemName: "doc.text.viewfinder")
                                .font(.title2).foregroundStyle(job.status.importStatusColor)
                        }
                        Text(job.sourceFilename ?? "Importación #\(job.id)")
                            .font(.title3.bold()).foregroundStyle(Color.stockLight)
                            .multilineTextAlignment(.center)
                        StatusBadge(text: job.status.importStatusLabel, color: job.status.importStatusColor)
                    }
                    .frame(maxWidth: .infinity).stockCard(padding: 20).padding(.horizontal)

                    InfoSection(title: "Detalles") {
                        InfoRow(label: "Tipo",    value: job.sourceType)
                        InfoRow(label: "Usuario", value: job.userName ?? "-")
                        if let at = job.createdAt   { InfoRow(label: "Creado",     value: at.readableDate) }
                        if let at = job.confirmedAt { InfoRow(label: "Confirmado", value: at.readableDate) }
                    }

                    // Ítems detectados
                    if let items = job.items, !items.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("ÍTEMS DETECTADOS (\(items.count))")
                                .font(.caption.bold()).foregroundStyle(Color.stockMuted)
                                .tracking(1.5).padding(.horizontal).padding(.bottom, 8)
                            LazyVStack(spacing: 8) {
                                ForEach(items) { item in
                                    HStack(spacing: 10) {
                                        Circle()
                                            .fill(item.status == "VALID"   ? Color.green :
                                                  item.status == "WARNING" ? Color.orange : Color.red)
                                            .frame(width: 8, height: 8)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.productName)
                                                .foregroundStyle(Color.stockLight).lineLimit(1)
                                            if let unit = item.unitOfMeasure {
                                                Text(unit).font(.caption2).foregroundStyle(Color.stockMuted)
                                            }
                                        }
                                        Spacer()
                                        Text(item.movementType == "ENTRY"
                                             ? "+\(item.quantity.stockFormatted)"
                                             : "-\(item.quantity.stockFormatted)")
                                            .font(.caption.monospacedDigit().bold())
                                            .foregroundStyle(item.movementType == "ENTRY" ? .green : .red)
                                        if let conf = item.confidence {
                                            Text("\(Int(conf * 100))%")
                                                .font(.caption2).foregroundStyle(Color.stockMuted)
                                        }
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                    .background(Color.stockCard)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Acciones PREVIEW
                    if job.status == "PREVIEW" {
                        VStack(spacing: 10) {
                            StockButton(title: "Confirmar e importar al inventario") {
                                Task { await vm.confirm(id: job.id); dismiss() }
                            }
                            Button("Descartar importación") {
                                Task { await vm.cancel(id: job.id); dismiss() }
                            }
                            .font(.subheadline)
                            .foregroundStyle(.red)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 16).padding(.bottom, 8)
            }
            .stockBackground()
            .navigationTitle("Importación #\(job.id)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }.foregroundStyle(Color.stockSubtle)
                }
            }
        }
    }
}
