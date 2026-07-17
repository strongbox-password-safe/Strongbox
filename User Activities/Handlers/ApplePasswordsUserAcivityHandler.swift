import UIKit

class ApplePasswordsUserActivityHandler: UserActivityHandler {
    var types: [String] { ["ASCredentialExchangeActivity"] }
    
    func handle(activity: NSUserActivity) {
        guard #available(iOS 26.0, *) else {
            return
        }

        Task { @MainActor in
            do {
                let result = try await ApplePasswordsImporter().importFromUserActivity(activity)
                NotificationCenter.default.post(name: .applePasswordsImportCompleted, object: result)
            } catch {
                NotificationCenter.default.post(name: .applePasswordsImportFailed, object: error)
            }
        }
    }
}

extension Notification.Name {
    static let applePasswordsImportCompleted = Notification.Name("applePasswordsImportCompleted")
    static let applePasswordsImportFailed = Notification.Name("applePasswordsImportFailed")
}
