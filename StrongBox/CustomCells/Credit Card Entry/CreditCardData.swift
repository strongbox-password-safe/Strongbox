import Foundation

struct CreditCardData {
    var name: String = ""
    var cardholderName: String = ""
    var cardType: CardType = .other
    var number: String = ""
    var verificationNumber: String = ""
    var expiryDate: String = ""
    var validFrom: String = ""
    var pin: String = ""
    var creditLimit: String = ""
    var cashWithdrawalLimit: String = ""
    var interestRate: String = ""
    var issueNumber: String = ""
    var customFields: [[String: String]] = []
    var notes: String = ""
    var tags: Set<String> = []
    
    
    var numberConcealed: Bool = false
    var verificationNumberConcealed: Bool = true
    var pinConcealed: Bool = true
    var customFieldsConcealed: [Bool] = []
    var customFieldsConceablable: [Bool] = []
    
    
    var customFieldsForRemoval: [String] = []
    
    
    var metadataEntries: [ItemMetadataEntry] = []
    
    static func availableCardTypes() -> [CardType] {
        return CardType.allCases
    }
} 


extension CreditCardData {
    func copy() -> CreditCardData {
        var copy = CreditCardData()
        copy.name = self.name
        copy.cardholderName = self.cardholderName
        copy.cardType = self.cardType
        copy.number = self.number
        copy.verificationNumber = self.verificationNumber
        copy.expiryDate = self.expiryDate
        copy.validFrom = self.validFrom
        copy.pin = self.pin
        copy.creditLimit = self.creditLimit
        copy.cashWithdrawalLimit = self.cashWithdrawalLimit
        copy.interestRate = self.interestRate
        copy.issueNumber = self.issueNumber
        copy.customFields = self.customFields
        copy.notes = self.notes
        copy.tags = self.tags
        copy.numberConcealed = self.numberConcealed
        copy.verificationNumberConcealed = self.verificationNumberConcealed
        copy.pinConcealed = self.pinConcealed
        copy.customFieldsConcealed = self.customFieldsConcealed
        copy.customFieldsConceablable = self.customFieldsConceablable
        copy.metadataEntries = self.metadataEntries
        return copy
    }
    
    func isEqual(to other: CreditCardData) -> Bool {
        self.name == other.name &&
        self.cardholderName == other.cardholderName &&
        self.cardType == other.cardType &&
        self.number == other.number &&
        self.verificationNumber == other.verificationNumber &&
        self.expiryDate == other.expiryDate &&
        self.validFrom == other.validFrom &&
        self.pin == other.pin &&
        self.creditLimit == other.creditLimit &&
        self.cashWithdrawalLimit == other.cashWithdrawalLimit &&
        self.interestRate == other.interestRate &&
        self.issueNumber == other.issueNumber &&
        self.customFields.elementsEqual(other.customFields, by: { $0 == $1 }) &&
        self.notes == other.notes &&
        self.tags.elementsEqual(other.tags, by: { $0 == $1 })
    }
}


