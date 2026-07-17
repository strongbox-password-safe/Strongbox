import Foundation

#if SETAPP
import Setapp
#endif

extension AppDelegate {
    @objc func showSetappIfNeeded() {
        #if SETAPP
        SetappManager.shared.showReleaseNotesWindowIfNeeded()
        #endif
    }
}
