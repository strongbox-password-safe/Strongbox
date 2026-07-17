import SwiftUI
import Notelet

extension View {
    
    
    
    
    
    
    @ViewBuilder
    func whatsNewSheet(forVersion version: String, onDismiss: @escaping () -> Void) -> some View {
        if #available(iOS 17.0, *) {
            noteletSheet(
                notes: ReleaseNotes.notes,
                version: .v(version),
                onDismiss: onDismiss,
                configuration: ReleaseNotes.configuration
            )
        } else {
            self
        }
    }
}

@available(iOS 17.0, *)
private struct WhatsNewHostView: View {
    let version: String
    let onDismiss: () -> Void
    var body: some View {
        
        Color.clear
            .whatsNewSheet(forVersion: version, onDismiss: onDismiss)
    }
}

@objc final class WhatsNewPresenter: NSObject {
    
    
    
    
    @objc static func presentIfNeeded(from presenter: UIViewController,
                                      launchCount: UInt,
                                      completion: @escaping () -> Void) {
        let decision = WhatsNewPresentation.decide(launchCount: launchCount)

        if decision.seedSeen {
            NoteletStorage.markCurrentVersionAsSeen()
        }

        let version = currentAppVersion()

        guard #available(iOS 17.0, *) else {
            completion()
            return
        }

        guard decision.present,
              presenter.presentedViewController == nil,
              hasUnseenNotes(for: version)
        else {
            completion()
            return
        }

        let host = UIHostingController(rootView: WhatsNewHostView(version: version, onDismiss: { [weak presenter] in
            
            NoteletStorage.markCurrentVersionAsSeen()

            if let presenter {
                presenter.dismiss(animated: false, completion: completion)
            } else {
                completion()
            }
        }))
        host.view.backgroundColor = .clear
        host.modalPresentationStyle = .overFullScreen
        presenter.present(host, animated: false)
    }

    
    
    @available(iOS 17.0, *)
    private static func hasUnseenNotes(for version: String) -> Bool {
        guard ReleaseNotes.availableVersions.contains(version) else { return false }
        let seen = UserDefaults.standard.string(forKey: NOTELET_APP_STORAGE_LATEST_SEEN_APP_VERSION_KEY)
        return seen != version
    }

    private static func currentAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
}
