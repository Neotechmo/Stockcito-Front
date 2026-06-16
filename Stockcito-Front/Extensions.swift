import SwiftUI
import UIKit

// MARK: - Date formatting

extension String {
    /// Parsea la fecha del backend y la devuelve en formato legible en español.
    /// Soporta ISO 8601 y el formato datetime de MySQL.
    var readableDate: String {
        guard let date = String.parseBackendDate(self) else { return self }
        return String.formatReadable(date)
    }

    // Formatos que puede devolver el backend (Java + MySQL)
    private static let inputFormatters: [DateFormatter] = [
        "yyyy-MM-dd'T'HH:mm:ss.SSS",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd HH:mm:ss.SSS",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm:ssZ",
        "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
        "yyyy-MM-dd'T'HH:mm:ssXXXXX",
    ].map { fmt in
        let f = DateFormatter()
        f.locale  = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = fmt
        return f
    }

    private static func parseBackendDate(_ string: String) -> Date? {
        for fmt in inputFormatters {
            if let date = fmt.date(from: string) { return date }
        }
        return nil
    }

    private static func formatReadable(_ date: Date) -> String {
        let now  = Date()
        let diff = now.timeIntervalSince(date)
        let cal  = Calendar.current

        switch diff {
        case ..<60:
            return "ahora mismo"
        case 60..<3600:
            let m = Int(diff / 60)
            return "hace \(m) min"
        case 3600..<7200:
            return "hace 1 hora"
        case 7200..<(6 * 3600):
            let h = Int(diff / 3600)
            return "hace \(h) horas"
        default:
            if cal.isDateInToday(date) {
                return "hoy, \(timeFmt.string(from: date))"
            } else if cal.isDateInYesterday(date) {
                return "ayer, \(timeFmt.string(from: date))"
            } else if diff < 7 * 86400 {
                return "\(dayFmt.string(from: date)), \(timeFmt.string(from: date))"
            } else {
                return fullFmt.string(from: date)
            }
        }
    }

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.dateFormat = "EEEE"   // lunes, martes…
        return f
    }()

    private static let fullFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.dateFormat = "d MMM yyyy, HH:mm"
        return f
    }()
}

// MARK: - Error alert helper

extension View {
    func errorAlert(error: Binding<String?>) -> some View {
        self.alert("Error", isPresented: Binding(
            get: { error.wrappedValue != nil },
            set: { if !$0 { error.wrappedValue = nil } }
        )) {
            Button("OK") { error.wrappedValue = nil }
        } message: {
            Text(error.wrappedValue ?? "")
        }
    }

    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    func keyboardDoneToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Listo") { hideKeyboard() }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.stockLight)
            }
        }
    }
}

// MARK: - Number formatting

extension Double {
    var stockFormatted: String {
        self == self.rounded() ? String(Int(self)) : String(format: "%.2f", self)
    }

    var priceFormatted: String {
        String(format: "$%.2f", self)
    }
}

// MARK: - Status colors & labels

extension String {
    var purchaseStatusColor: Color {
        switch self {
        case "PENDING":   return .orange
        case "PURCHASED": return .green
        case "CANCELLED": return .red
        default:          return .gray
        }
    }

    var purchaseStatusLabel: String {
        switch self {
        case "PENDING":   return "Pendiente"
        case "PURCHASED": return "Comprado"
        case "CANCELLED": return "Cancelado"
        default:          return self
        }
    }

    var importStatusColor: Color {
        switch self {
        case "CONFIRMED":  return .green
        case "PREVIEW":    return .blue
        case "PROCESSING": return .orange
        case "PENDING":    return .yellow
        case "FAILED":     return .red
        case "CANCELLED":  return .gray
        default:           return .gray
        }
    }

    var importStatusLabel: String {
        switch self {
        case "CONFIRMED":  return "Confirmado"
        case "PREVIEW":    return "Vista previa"
        case "PROCESSING": return "Procesando"
        case "PENDING":    return "Pendiente"
        case "FAILED":     return "Fallido"
        case "CANCELLED":  return "Cancelado"
        default:           return self
        }
    }

    var movementTypeLabel: String {
        self == "ENTRY" ? "Entrada" : "Salida"
    }

    var movementTypeColor: Color {
        self == "ENTRY" ? .green : .red
    }
}
