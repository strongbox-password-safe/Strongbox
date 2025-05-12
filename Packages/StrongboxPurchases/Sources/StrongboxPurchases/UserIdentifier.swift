import Foundation

// Local identifier used to login to RevenueCat to sync & restore purchases.
struct UserIdentifier {
    @UserDefault("strongbox.id.5", default: UUID().uuidString)
    static var id: String
}
