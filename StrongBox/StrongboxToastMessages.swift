//
//  StrongboxToastMessages.swift
//  Strongbox
//
//  Created by Mark on 28/02/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

import Foundation
import SwiftMessages

@objc class StrongboxToastMessages: NSObject {
    @objc public enum ToastMessageCategory: Int {
        case info
        case warning
        case error
    }

    @objc public enum ToastIcon: Int {
        case sync
        case info
    }

    class func getImage(icon: ToastIcon = .info) -> UIImage {
        switch icon {
        case .info:
            return UIImage(systemName: "info.circle")!
        case .sync:
            return UIImage(systemName: "arrow.triangle.2.circlepath")!
        }
    }

    @MainActor @objc public class func showToast(title: String, body: String, category _: ToastMessageCategory = .info, icon: ToastIcon = .info) {
        var config = SwiftMessages.Config()

        config.presentationStyle = .top
        config.presentationContext = .window(windowLevel: .statusBar)

        config.duration = .seconds(seconds: 1.0)

        let view = MessageView.viewFromNib(layout: .cardView)

        view.configureTheme(backgroundColor: .systemBlue, foregroundColor: .white)

        view.configureDropShadow()

        let image = getImage(icon: icon)

        view.configureContent(title: title, body: body, iconImage: image)
        view.button?.isHidden = true

        SwiftMessages.show(config: config, view: view)
    }

    @MainActor @objc public class func showSlimInfoStatusBar(body: String, delay: TimeInterval) {
        var config = SwiftMessages.Config()

        config.presentationStyle = .top
        config.presentationContext = .window(windowLevel: .statusBar)

        config.duration = .seconds(seconds: delay)

        let view = MessageView.viewFromNib(layout: .statusLine)

        view.configureTheme(backgroundColor: .systemBlue, foregroundColor: .white)

        view.configureContent(title: "", body: body)

        SwiftMessages.show(config: config, view: view)
    }

    @MainActor @objc public class func hideAll() {
        SwiftMessages.hideAll()
    }

    @MainActor @objc public class func showSyncIssueBanner(buttonHandler: (() -> Void)?) {
        var config = SwiftMessages.Config()

        config.presentationStyle = .top
        config.presentationContext = .window(windowLevel: .statusBar)

        config.duration = .seconds(seconds: 5)

        let view: SyncIssueMessageView = try! SwiftMessages.viewFromNib(named: "SyncIssueMessageView")

        view.configureTheme(backgroundColor: .systemOrange, foregroundColor: .white)

        view.configureDropShadow()

        let image = getImage(icon: .sync)

        view.configureContent(title: NSLocalizedString("nextgen_sync_issue_toast_title", comment: "Sync Issue"),
                              body: NSLocalizedString("nextgen_sync_issue_toast_message", comment: "Strongbox could not sync..."),
                              iconImage: image,
                              iconText: nil,
                              buttonImage: nil,
                              buttonTitle: NSLocalizedString("generic_more_with_ellipsis", comment: "More..."),
                              buttonTapHandler: { _ in
                                  SwiftMessages.hide()
                                  buttonHandler?()
                              })

        SwiftMessages.show(config: config, view: view)
    }
}
