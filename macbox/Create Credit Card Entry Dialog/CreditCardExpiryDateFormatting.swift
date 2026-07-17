import Foundation

enum CreditCardExpiryDateFormatting {
    static func parseDate(from string: String, timeZone: TimeZone = .current) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let compact = trimmed.replacingOccurrences(of: " ", with: "")

        for dateFormat in ["MM/yy", "MM/yyyy"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = timeZone
            formatter.dateFormat = dateFormat
            if let date = formatter.date(from: compact) {
                return date
            }
        }

        let mediumFormatter = DateFormatter()
        mediumFormatter.dateStyle = .medium
        mediumFormatter.timeStyle = .none
        mediumFormatter.timeZone = timeZone
        return mediumFormatter.date(from: trimmed)
    }

    
    
    static func format(_ date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.month, .year], from: date)
        guard let month = components.month, let year = components.year else { return "" }

        return String(format: "%02d / %02d", month, year % 100)
    }

    
    
    static func legacyMonthShiftCorrection(parsedExpiry: Date?, entryExpires: Date?, timeZone: TimeZone = .current) -> Date? {
        guard let expires = entryExpires, let parsed = parsedExpiry else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let oneMonthBehind = calendar.date(byAdding: .month, value: -1, to: expires) else { return nil }

        let parsedComponents = calendar.dateComponents([.year, .month], from: parsed)
        let behindComponents = calendar.dateComponents([.year, .month], from: oneMonthBehind)

        return parsedComponents == behindComponents ? expires : nil
    }
}
