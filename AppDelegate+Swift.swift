import AuthenticationServices
import Foundation
#if SUBSCRIPTIONS
import Setapp
#endif

extension AppDelegate {
    
    @objc func processUserActivity(userActivity: NSUserActivity?) {
        guard let activity = userActivity else { return }
                
        guard let handler = UserActivityHandlers.handlers.first(where: {
            $0.types.contains(activity.activityType)
        }) else { return }
        
        handler.handle(activity: activity)
    }
    
    
    @objc func initializeSetappIfNeeded() {
        #if SUBSCRIPTIONS
        SetappManager.shared.start(with: .default)
        #endif
    }
    
    @objc func initializeSuperWall() {
        #if SUBSCRIPTIONS
        SuperwallService.configure()
        #endif
    }

    @objc func processSetappURL(
        url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        #if SUBSCRIPTIONS
        if SetappManager.shared.canOpen(url: url) {
          return SetappManager.shared.open(url: url, options: options) { result in
            switch result {
            case let .success(setappSubscription):
              print("Successfully unlocked new features!")
              print("Setapp subscription:", setappSubscription)
            case let .failure(error):
              print("Failed to unlock new app features due to the error:", error)
            }
          }
        } else {
            return false
        }
        #else
        return false
        #endif
    }
}
