import UIKit

protocol UserActivityHandler {
    var types: [String] { get }
    
    func handle(activity: NSUserActivity)
}

struct UserActivityHandlers {
    static let handlers: [any UserActivityHandler] = [
        ApplePasswordsUserActivityHandler()
    ]
}
