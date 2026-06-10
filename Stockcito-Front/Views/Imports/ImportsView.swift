import SwiftUI
import PhotosUI
import Vision
import CryptoKit
import CoreImage
import ImageIO

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
    @State private var pendingPreviewJob: ImportJob?
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
            .sheet(isPresented: $showForm, onDismiss: {
                if let preview = pendingPreviewJob {
                    pendingPreviewJob = nil
                    selectedJob = preview
                }
            }) {
                ImportPreviewSheet(currentUserId: session.currentUser?.id ?? 0) { preview in
                    await vm.load()
                    pendingPreviewJob = preview
                }
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
    let onSave: (ImportJob) async -> Void

    @State private var photosItem: PhotosPickerItem?
    @State private var ticketImage: UIImage?
    @State private var isOCRRunning = false
    @State private var rawText = ""
    @State private var detectedItems: [ImportItemRequest] = []
    @State private var products: [Product] = []
    @State private var fileHash: String?
    @State private var sourceFilename = ""
    @State private var notes = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var newProductDraft: NewProductDraft?

    @Environment(\.dismiss) private var dismiss

    private var hasLinkedItems: Bool {
        detectedItems.contains { $0.productId != nil }
    }

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
                                    Text("\(detectedItems.count) productos listos para preview")
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

                        FormSection(title: "Texto detectado") {
                            FormField(label: "Contenido del ticket") {
                                TextField(
                                    "2 BOCADILLO JAMÓN IB 3,95 7,90\n2 HORNAZO, RACIÓN 4,90 9,80",
                                    text: $rawText,
                                    axis: .vertical
                                )
                                .lineLimit(5...10)
                                .stockField()
                            }
                        }

                        FormSection(title: "Notas") {
                            FormField(label: "Observaciones adicionales") {
                                TextField("Opcional", text: $notes, axis: .vertical)
                                    .lineLimit(2...3).stockField()
                            }
                        }

                        if !detectedItems.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("PRODUCTOS DETECTADOS (\(detectedItems.count))")
                                    .font(.caption.bold()).foregroundStyle(Color.stockMuted)
                                    .tracking(1.5).padding(.horizontal).padding(.bottom, 8)
                                LazyVStack(spacing: 8) {
                                    ForEach(Array(detectedItems.enumerated()), id: \.offset) { index, item in
                                        HStack(spacing: 10) {
                                            Circle()
                                                .fill(item.status == "VALID" ? Color.green : Color.orange)
                                                .frame(width: 8, height: 8)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.productName)
                                                    .foregroundStyle(Color.stockLight).lineLimit(1)
                                                Text(item.rawLine)
                                                    .font(.caption2).foregroundStyle(Color.stockMuted)
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                            VStack(alignment: .trailing, spacing: 2) {
                                                Text("+\(item.quantity.stockFormatted)")
                                                    .font(.caption.monospacedDigit().bold())
                                                    .foregroundStyle(.green)
                                                Menu {
                                                    ForEach(products) { product in
                                                        Button(product.name) {
                                                            linkDetectedItem(at: index, to: product)
                                                        }
                                                    }
                                                    Button {
                                                        newProductDraft = NewProductDraft(itemIndex: index, name: item.productName)
                                                    } label: {
                                                        Label("Crear producto", systemImage: "plus")
                                                    }
                                                } label: {
                                                    Text(item.productId == nil ? "Asociar" : "Válido")
                                                        .font(.caption2.bold())
                                                        .foregroundStyle(item.productId == nil ? Color.orange : Color.green)
                                                }
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
                    .disabled(isLoading || isOCRRunning || ticketImage == nil || rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || detectedItems.isEmpty || !hasLinkedItems)
                    .foregroundStyle(Color.stockLight)
                }
            }
            // Reaccionar cuando el usuario elige una foto
            .onChange(of: photosItem) { _, newItem in
                guard let newItem else { return }
                Task { await loadAndOCR(item: newItem) }
            }
            .onChange(of: rawText) { _, _ in
                Task { await refreshDetectedItems() }
            }
            .sheet(item: $newProductDraft) { draft in
                ProductFormView(product: nil, initialName: draft.name, onSavedProduct: { created in
                    await loadProductsIfNeeded(force: true)
                    linkDetectedItem(at: draft.itemIndex, to: created)
                })
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
        fileHash = Self.sha256Hex(data)
        rawText = ""
        detectedItems = []

        // Si no tiene nombre aún, usar timestamp
        if sourceFilename.isEmpty {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyyMMdd_HHmmss"
            sourceFilename = "ticket_\(fmt.string(from: Date())).jpg"
        }

        // OCR con Vision
        let extracted = await recognizeText(in: uiImage)
        await loadProductsIfNeeded()
        if !extracted.isEmpty {
            rawText = extracted
            await refreshDetectedItems()
            if detectedItems.isEmpty {
                error = "Se detectó texto, pero no se encontraron productos. Puedes corregir el texto detectado manualmente."
            }
        } else {
            error = "No se pudo leer texto automáticamente. Escribe o pega el contenido del ticket en el campo de texto."
        }
    }

    private func recognizeText(in image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }

        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        async let originalText = performOCR(on: cgImage, orientation: orientation)
        async let enhancedText = performEnhancedOCR(on: cgImage, orientation: orientation)

        let candidates = await [originalText, enhancedText]
        return candidates.max { lhs, rhs in
            Self.ocrScore(lhs) < Self.ocrScore(rhs)
        } ?? ""
    }

    private func performEnhancedOCR(on cgImage: CGImage, orientation: CGImagePropertyOrientation) async -> String {
        guard let enhancedImage = Self.enhancedTicketImage(from: cgImage) else { return "" }
        return await performOCR(on: enhancedImage, orientation: orientation)
    }

    private func performOCR(on cgImage: CGImage, orientation: CGImagePropertyOrientation) async -> String {
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { req, _ in
                let lines = (req.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string } ?? []
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel       = .accurate
            request.recognitionLanguages   = ["es-ES", "es-MX", "es", "en"]
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            request.customWords = [
                "BOCADILLO", "JAMÓN", "JAMON", "HORNAZO", "RACIÓN", "RACION",
                "UDS", "DESCRIPCION", "PRECIO", "IMPORTE"
            ]

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            try? handler.perform([request])
        }
    }

    private func loadProductsIfNeeded(force: Bool = false) async {
        guard force || products.isEmpty else { return }
        products = (try? await APIClient.shared.get("v1/products")) ?? []
    }

    private func refreshDetectedItems() async {
        await loadProductsIfNeeded()
        detectedItems = Self.parseItems(from: rawText, products: products)
    }

    private func linkDetectedItem(at index: Int, to product: Product) {
        guard detectedItems.indices.contains(index) else { return }
        let item = detectedItems[index]
        detectedItems[index] = ImportItemRequest(
            productId: product.id,
            productName: product.name,
            movementType: item.movementType,
            quantity: item.quantity,
            unitOfMeasure: product.unitOfMeasure,
            confidence: max(item.confidence, 0.9),
            rawLine: item.rawLine,
            status: "VALID"
        )
    }

    private static func enhancedTicketImage(from cgImage: CGImage) -> CGImage? {
        let context = CIContext(options: nil)
        let input = CIImage(cgImage: cgImage)

        let scaled = input
            .applyingFilter("CILanczosScaleTransform", parameters: [
                kCIInputScaleKey: 2.0,
                kCIInputAspectRatioKey: 1.0
            ])
            .applyingFilter("CIPhotoEffectMono")
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 2.2,
                kCIInputBrightnessKey: 0.12,
                kCIInputSaturationKey: 0.0
            ])
            .applyingFilter("CISharpenLuminance", parameters: [
                kCIInputSharpnessKey: 0.8
            ])

        return context.createCGImage(scaled, from: scaled.extent)
    }

    private static func ocrScore(_ text: String) -> Int {
        let usefulWords = ["BOCADILLO", "HORNAZO", "UDS", "DESCRIP", "PRECIO", "IMPORTE", "TOTAL"]
        let normalized = normalizeForMatch(text)
        let usefulHits = usefulWords.reduce(0) { $0 + (normalized.contains($1) ? 10 : 0) }
        let lineCount = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        return usefulHits + lineCount + text.count / 20
    }

    private static func parseItems(from text: String, products: [Product]) -> [ImportItemRequest] {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var items: [ImportItemRequest] = []
        var pendingQuantity: Double?
        var pendingRawLine: String?

        for line in lines {
            if let quantity = quantityOnly(in: line) {
                pendingQuantity = quantity
                pendingRawLine = line
                continue
            }

            if let item = parseItem(from: line, products: products) {
                items.append(item)
                pendingQuantity = nil
                pendingRawLine = nil
                continue
            }

            if let quantity = pendingQuantity,
               let item = parseItem(fromDescriptionLine: line, quantity: quantity, rawPrefix: pendingRawLine, products: products) {
                items.append(item)
                pendingQuantity = nil
                pendingRawLine = nil
            }
        }

        return items.isEmpty ? parseColumnarTicket(lines: lines, products: products) : items
    }

    private static func parseItem(from line: String, products: [Product]) -> ImportItemRequest? {
        let parts = line.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
        guard parts.count == 2,
              let quantity = Double(parts[0].replacingOccurrences(of: ",", with: ".")),
              quantity > 0 else { return nil }

        return parseItem(fromDescriptionLine: String(parts[1]), quantity: quantity, rawPrefix: String(parts[0]), products: products)
    }

    private static func parseItem(
        fromDescriptionLine line: String,
        quantity: Double,
        rawPrefix: String?,
        products: [Product]
    ) -> ImportItemRequest? {
        guard containsPriceToken(line) else { return nil }

        let productName = cleanProductName(line)
        guard productName.count >= 2, !productName.allSatisfy({ $0.isNumber }) else { return nil }
        guard !isIgnoredTicketLabel(productName) else { return nil }

        let matchResult = bestProductMatch(for: productName, in: products)
        let hasValidMatch = (matchResult?.confidence ?? 0) >= 0.75
        let rawLine = [rawPrefix, line].compactMap { $0 }.joined(separator: " ")

        return ImportItemRequest(
            productId: hasValidMatch ? matchResult?.product.id : nil,
            productName: hasValidMatch ? (matchResult?.product.name ?? productName) : productName,
            movementType: "ENTRY",
            quantity: quantity,
            unitOfMeasure: matchResult?.product.unitOfMeasure ?? "pieza",
            confidence: hasValidMatch ? (matchResult?.confidence ?? 0.8) : 0.8,
            rawLine: rawLine,
            status: hasValidMatch ? "VALID" : "WARNING"
        )
    }

    private static func parseColumnarTicket(lines: [String], products: [Product]) -> [ImportItemRequest] {
        var productLines: [String] = []
        var moneyValues: [Double] = []
        var hasSeenDescriptionHeader = false

        for line in lines {
            let normalized = normalizeForMatch(line)

            if normalized.contains("DESCRIPCION") {
                hasSeenDescriptionHeader = true
                continue
            }

            if !hasSeenDescriptionHeader { continue }
            if normalized.contains("SUBTOTAL") || normalized == "TOTAL" || normalized.contains("EFECTIVO") || normalized.contains("CAMBIO") {
                break
            }

            if let amount = moneyOnly(in: line) {
                moneyValues.append(amount)
                continue
            }

            let productName = cleanProductName(line)
            if productName.count >= 2,
               !isIgnoredTicketLabel(productName),
               !containsPriceToken(productName) {
                productLines.append(productName)
            }
        }

        guard !productLines.isEmpty else { return [] }

        let itemCount = productLines.count
        let unitPrices = Array(moneyValues.prefix(itemCount))
        let importes = Array(moneyValues.dropFirst(itemCount).prefix(itemCount))

        return productLines.enumerated().map { index, productName in
            let unitPrice = index < unitPrices.count ? unitPrices[index] : nil
            let importe = index < importes.count ? importes[index] : nil
            let inferredQuantity = inferQuantity(unitPrice: unitPrice, importe: importe) ?? 1
            return makeImportItem(
                productName: productName,
                quantity: inferredQuantity,
                rawLine: [quantityPrefix(inferredQuantity), productName, unitPrice?.stockFormatted, importe?.stockFormatted]
                    .compactMap { $0 }
                    .joined(separator: " "),
                products: products,
                fallbackConfidence: inferredQuantity > 1 ? 0.78 : 0.65
            )
        }
    }

    private static func makeImportItem(
        productName: String,
        quantity: Double,
        rawLine: String,
        products: [Product],
        fallbackConfidence: Double
    ) -> ImportItemRequest {
        let matchResult = bestProductMatch(for: productName, in: products)
        let hasValidMatch = (matchResult?.confidence ?? 0) >= 0.75

        return ImportItemRequest(
            productId: hasValidMatch ? matchResult?.product.id : nil,
            productName: hasValidMatch ? (matchResult?.product.name ?? productName) : productName,
            movementType: "ENTRY",
            quantity: quantity,
            unitOfMeasure: matchResult?.product.unitOfMeasure ?? "pieza",
            confidence: hasValidMatch ? (matchResult?.confidence ?? fallbackConfidence) : fallbackConfidence,
            rawLine: rawLine,
            status: hasValidMatch ? "VALID" : "WARNING"
        )
    }

    private static func cleanProductName(_ value: String) -> String {
        var tokens = value.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        while let last = tokens.last, isPriceToken(last) {
            tokens.removeLast()
        }
        while let last = tokens.last, isPriceToken(last) {
            tokens.removeLast()
        }

        let cleaned = tokens
            .joined(separator: " ")
            .replacingOccurrences(of: #"[^A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9\s\-_]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
    }

    private static func isPriceToken(_ token: String) -> Bool {
        let cleaned = token
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return cleaned.range(of: #"^\d+(?:\.\d{1,2})?$"#, options: .regularExpression) != nil
    }

    private static func containsPriceToken(_ line: String) -> Bool {
        line.split(whereSeparator: { $0.isWhitespace }).contains { isPriceToken(String($0)) }
    }

    private static func quantityOnly(in line: String) -> Double? {
        let normalized = line.replacingOccurrences(of: ",", with: ".")
        guard normalized.range(of: #"^\d+(?:\.\d+)?$"#, options: .regularExpression) != nil,
              let value = Double(normalized),
              value > 0 else { return nil }
        return value
    }

    private static func moneyOnly(in line: String) -> Double? {
        let cleaned = line
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "E", with: "")
            .replacingOccurrences(of: "e", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.range(of: #"^\d+(?:\.\d{1,2})$"#, options: .regularExpression) != nil else { return nil }
        return Double(cleaned)
    }

    private static func inferQuantity(unitPrice: Double?, importe: Double?) -> Double? {
        guard let unitPrice, let importe, unitPrice > 0 else { return nil }
        let quantity = (importe / unitPrice).rounded()
        guard quantity > 0, abs((unitPrice * quantity) - importe) < 0.03 else { return nil }
        return quantity
    }

    private static func quantityPrefix(_ quantity: Double) -> String {
        quantity == quantity.rounded() ? String(Int(quantity)) : String(format: "%.2f", quantity)
    }

    private static func isIgnoredTicketLabel(_ productName: String) -> Bool {
        let ignoredLabels = [
            "UDS", "DESCRIPCION", "PRECIO", "IMPORTE", "SUBTOTAL", "TOTAL",
            "EFECTIVO", "CAMBIO", "TICKET", "TELF", "NIF", "LE HA ATENDIDO"
        ]
        let normalized = normalizeForMatch(productName)
        return ignoredLabels.contains { normalized.contains($0) }
    }

    private static func bestProductMatch(for name: String, in products: [Product]) -> (product: Product, confidence: Double)? {
        let normalizedName = normalizeForMatch(name)
        guard !normalizedName.isEmpty else { return nil }

        return products.compactMap { product -> (product: Product, confidence: Double)? in
            let normalizedProduct = normalizeForMatch(product.name)
            guard !normalizedProduct.isEmpty else { return nil }

            let confidence: Double
            if normalizedName == normalizedProduct {
                confidence = 0.95
            } else if normalizedName.contains(normalizedProduct) || normalizedProduct.contains(normalizedName) {
                confidence = 0.9
            } else {
                let nameTokens = Set(normalizedName.split(separator: " "))
                let productTokens = Set(normalizedProduct.split(separator: " "))
                let overlap = nameTokens.intersection(productTokens).count
                let base = max(min(nameTokens.count, productTokens.count), 1)
                let ratio = Double(overlap) / Double(base)
                confidence = ratio >= 0.75 ? 0.85 : (ratio >= 0.55 ? 0.7 : 0)
            }

            return confidence > 0 ? (product, confidence) : nil
        }
        .max { $0.confidence < $1.confidence }
    }

    private static func normalizeForMatch(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_MX"))
            .uppercased()
            .replacingOccurrences(of: #"[^A-Z0-9\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    // MARK: Enviar al backend

    private func submit() async {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            error = "El contenido del ticket no puede estar vacío."
            return
        }
        guard !detectedItems.isEmpty else {
            error = "No se detectaron productos para importar. El backend requiere al menos un item."
            return
        }
        guard hasLinkedItems else {
            error = "Asocia al menos un producto detectado con un producto de Stockcito para poder actualizar inventario."
            return
        }

        isLoading = true; defer { isLoading = false }

        let input = ImportPreviewRequest(
            userId:         currentUserId,
            sourceType:     "IMAGE",
            sourceFilename: sourceFilename.isEmpty ? nil : sourceFilename,
            fileHash:       fileHash,
            rawText:        text,
            aiModel:        "vision-local",
            notes:          notes.isEmpty ? "Ticket escaneado desde iOS" : notes,
            items:          detectedItems
        )
        do {
            let preview: ImportJob = try await APIClient.shared.postJSON("v1/imports/preview", body: input)
            await onSave(preview)
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

private extension CGImagePropertyOrientation {
    init(_ imageOrientation: UIImage.Orientation) {
        switch imageOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

private struct NewProductDraft: Identifiable {
    let id = UUID()
    let itemIndex: Int
    let name: String
}
