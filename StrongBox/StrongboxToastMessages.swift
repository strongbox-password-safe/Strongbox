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
        case watch
    }

    class func getImage(icon: ToastIcon = .info) -> UIImage {
        switch icon {
        case .info:
            return UIImage(systemName: "info.circle")!
        case .sync:
            return UIImage(systemName: "arrow.triangle.2.circlepath")!
        case .watch:
            return UIImage(systemName: "applewatch")!
        }
    }

    

    @MainActor @objc public class func showInfo(title: String, body: String) {
        showToast(title: title, body: body, category: .info)
    }

    @MainActor @objc public class func showWarning(title: String, body: String) {
        showToast(title: title, body: body, category: .warning)
    }

    @MainActor @objc public class func showError(title: String, body: String) {
        showToast(title: title, body: body, duration: 2.5, category: .error)
    }

    @MainActor @objc public class func showToast(title: String, body: String, duration: TimeInterval = 1.5, category: ToastMessageCategory = .info, icon: ToastIcon = .info) {
        var config = SwiftMessages.Config()

        config.presentationStyle = .top
        config.presentationContext = .window(windowLevel: .statusBar)
        config.duration = .seconds(seconds: duration)

        let view = MessageView.viewFromNib(layout: .cardView)

        switch category {
        case .info:
            view.configureTheme(backgroundColor: .systemBlue, foregroundColor: .white)
        case .warning:
            view.configureTheme(backgroundColor: .systemOrange, foregroundColor: .white)
        case .error:
            view.configureTheme(backgroundColor: .systemRed, foregroundColor: .white)
        }

        view.configureDropShadow()

        let image = getImage(icon: icon)

        view.configureContent(title: title, body: body, iconImage: image)
        view.button?.isHidden = true

        SwiftMessages.show(config: config, view: view)
    }

    

    @MainActor @objc public class func showSlim(title: String) {
        showSlim(title: title, delay: 1.5)
    }

    @MainActor @objc public class func showSlim(title: String, delay: TimeInterval, icon: ToastIcon = .info) {
        var config = SwiftMessages.Config()

        config.presentationStyle = .top
        config.presentationContext = .window(windowLevel: .statusBar)

        config.duration = .seconds(seconds: delay)

        let view = MessageView.viewFromNib(layout: .statusLine)

        view.configureTheme(backgroundColor: .systemBlue, foregroundColor: .white)

        let image = getImage(icon: icon)
        view.configureContent(title: "", body: title, iconImage: image)

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
