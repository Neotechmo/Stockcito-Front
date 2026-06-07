import Foundation

// MARK: - Utility

struct ApiMessage: Codable {
    let message: String
}

// MARK: - Auth

struct AuthResponse: Codable {
    let token: String
    let user: User
}

struct LoginInput: Encodable {
    let email: String
    let password: String
}

struct RegisterInput: Encodable {
    let name: String
    let email: String
    let password: String
}

struct UserUpdateInput: Encodable {
    let name: String
    let email: String
    let password: String?   // nil = no cambiar contraseña
}

// MARK: - User

struct User: Codable, Identifiable {
    let id: Int64
    let name: String
    let email: String
    let role: String?
    let isActive: Bool?
    let createdAt: String?
    let updatedAt: String?
}

// MARK: - Category

struct Category: Codable, Identifiable {
    let id: Int64
    let name: String
    let description: String?
    let isActive: Bool?
    let createdAt: String?
    let updatedAt: String?
}

struct CategoryInput: Encodable {
    let name: String
    let description: String?
}

// MARK: - Supplier

struct Supplier: Codable, Identifiable {
    let id: Int64
    let name: String
    let contactName: String?
    let email: String?
    let phone: String?
    let address: String?
    let notes: String?
    let isActive: Bool?
    let createdAt: String?
    let updatedAt: String?
}

struct SupplierInput: Encodable {
    let name: String
    let contactName: String?
    let email: String?
    let phone: String?
    let address: String?
    let notes: String?
}

// MARK: - Product

struct Product: Codable, Identifiable {
    let id: Int64
    let categoryId: Int64
    let categoryName: String?
    let supplierId: Int64?
    let supplierName: String?
    let name: String
    let sku: String?
    let description: String?
    let unitOfMeasure: String
    let minStock: Double?
    let currentStock: Double?
    let unitPrice: Double?
    let barcode: String?
    let isActive: Bool?
    let createdAt: String?
    let updatedAt: String?
}

struct ProductInput: Encodable {
    let categoryId: Int64
    let supplierId: Int64?
    let name: String
    let sku: String?
    let description: String?
    let unitOfMeasure: String
    let minStock: Double
    let currentStock: Double
    let unitPrice: Double?
    let barcode: String?
}

// MARK: - Inventory Movement

struct InventoryMovement: Codable, Identifiable {
    let id: Int64
    let productId: Int64
    let productName: String?
    let userId: Int64
    let userName: String?
    let movementType: String
    let quantity: Double
    let stockBefore: Double?
    let stockAfter: Double?
    let movementDate: String?
    let notes: String?
    let originalText: String?
    let createdAt: String?
}

struct MovementInput: Encodable {
    let productId: Int64
    let userId: Int64
    let movementType: String
    let quantity: Double
    let notes: String?
}

// MARK: - Inventory Summary

struct InventorySummary: Codable, Identifiable {
    let productId: Int64
    let productName: String
    let sku: String?
    let currentStock: Double
    let minimumStock: Double
    let unitOfMeasure: String
    let status: String

    var id: Int64 { productId }

    var isLow: Bool { status == "LOW" || currentStock <= minimumStock }
}

// MARK: - Purchase Request

struct PurchaseRequest: Codable, Identifiable {
    let id: Int64
    let productId: Int64
    let productName: String?
    let requestedBy: Int64
    let requestedByName: String?
    let approvedBy: Int64?
    let approvedByName: String?
    let quantity: Double
    let status: String
    let notes: String?
    let requestedAt: String?
    let updatedAt: String?
}

struct PurchaseRequestInput: Encodable {
    let productId: Int64
    let requestedBy: Int64
    let quantity: Double
    let notes: String?
}

struct PurchaseStatusInput: Encodable {
    let status: String
    let approvedBy: Int64?
}

// MARK: - Import Job

struct ImportJob: Codable, Identifiable {
    let id: Int64
    let userId: Int64
    let userName: String?
    let sourceType: String
    let sourceFilename: String?
    let fileHash: String?
    let status: String
    let rawText: String?
    let aiModel: String?
    let notes: String?
    let createdAt: String?
    let confirmedAt: String?
    let updatedAt: String?
    let items: [ImportItem]?
}

struct ImportJobInput: Encodable {
    let userId: Int64
    let sourceType: String
    let sourceFilename: String?
    let rawText: String?
    let aiModel: String?
    let notes: String?
}

struct ImportItem: Codable, Identifiable {
    let id: Int64
    let importJobId: Int64
    let productId: Int64?
    let productName: String
    let movementType: String
    let quantity: Double
    let unitOfMeasure: String?
    let confidence: Double?
    let rawLine: String?
    let status: String
    let duplicateOf: Int64?
    let createdAt: String?
}

// MARK: - AI Summary

struct SummaryResponse: Codable {
    let summary: String
    let model: String
}

struct SummaryInput: Encodable {
    let daysBack: Int?
    let maxSentences: Int?
    let language: String?

    init(daysBack: Int? = nil, maxSentences: Int? = nil, language: String? = "español") {
        self.daysBack = daysBack
        self.maxSentences = maxSentences
        self.language = language
    }
}
