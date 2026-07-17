import Foundation

extension String {
    
    
    
    func formattedAsExpiryDate() -> String {
        let digits = self.filter { $0.isNumber }
        let prefix = digits.prefix(4)
        switch prefix.count {
        case 0...1:
            return String(prefix)
        case 2:
            return "\(prefix.prefix(2))"
        case 3:
            return "\(prefix.prefix(2)) / \(prefix.suffix(1))"
        case 4:
            let mm = prefix.prefix(2)
            let yy = prefix.suffix(2)
            return "\(mm) / \(yy)"
        default:
            return "\(prefix.prefix(2)) / \(prefix.suffix(2))"
        }
    }
    
    
    
    func formattedAsCreditCardNumber(usingAmexFormat: Bool = false) -> String {
        let digits = self.filter { $0.isASCII && $0.isWholeNumber }
        
        let maxLength = usingAmexFormat ? 15 : 16
        let truncated = String(digits.prefix(maxLength))
        
        guard !truncated.isEmpty else { return "" }

        let groupSizes = usingAmexFormat ? [4, 6, 5] : [4, 4, 4, 4]
        var groups: [String] = []

        var currentIndex = truncated.startIndex
        for size in groupSizes {
            guard currentIndex < truncated.endIndex else { break }

            let remainingCharacters = truncated.distance(from: currentIndex, to: truncated.endIndex)
            let endIndex = truncated.index(currentIndex, offsetBy: min(size, remainingCharacters))
            groups.append(String(truncated[currentIndex..<endIndex]))

            currentIndex = endIndex
        }

        return groups.joined(separator: "-")
    }
    
    
    
    func formattedAsMoney() -> String {
        guard !self.isEmpty else { return "" }
        
        
        let digits = self.filter(\.isWholeNumber)
        guard !digits.isEmpty else { return "" }
        
        
        guard let number = Int(digits) else { return digits }
        
        
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        
        
        let defaultSeparator = formatter.groupingSeparator ?? ","
        
        
        if defaultSeparator.trimmingCharacters(in: .whitespaces).isEmpty {
            formatter.groupingSeparator = ","
        }
        
        return formatter.string(from: NSNumber(value: number)) ?? digits
    }
    
    
    
    func formattedAsMoneyWithCommas() -> String {
        guard !self.isEmpty else { return "" }
        
        
        let digits = self.filter(\.isWholeNumber)
        guard !digits.isEmpty else { return "" }
        
        
        guard let number = Int(digits) else { return digits }
        
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US")
        formatter.usesGroupingSeparator = true
        
        return formatter.string(from: NSNumber(value: number)) ?? digits
    }
}

extension String {
    var onlyNumbers: String {
        let numbersOnlyString = self.filter { $0.isNumber }
        return numbersOnlyString
    }
}
