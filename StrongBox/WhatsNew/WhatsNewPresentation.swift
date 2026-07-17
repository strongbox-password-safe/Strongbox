import Foundation




enum WhatsNewPresentation {
    
    
    static let brandNewInstallLaunchThreshold: UInt = 3

    static func decide(launchCount: UInt) -> (present: Bool, seedSeen: Bool) {
        if launchCount < brandNewInstallLaunchThreshold {
            return (present: false, seedSeen: true)
        }
        return (present: true, seedSeen: false)
    }
}
