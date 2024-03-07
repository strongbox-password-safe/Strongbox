//
//  PasswordHistoryHelper.swift
//  MacBox
//
//  Created by Strongbox on 06/02/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Foundation

public class PasswordHistoryHelper {
    class func getHeaderMenuItem(_ title: String, headline: Bool = false) -> NSMenuItem {
        let menuItemHeader = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        menuItemHeader.isEnabled = false
        menuItemHeader.target = self

        let attributes: [NSAttributedString.Key: Any] = [.font: headline ? FontManager.shared.headlineFont : FontManager.shared.bodyFont,
                                                         .foregroundColor: NSColor.secondaryLabelColor]

        let mutStr = NSMutableAttributedString(string: title, attributes: attributes)
        menuItemHeader.attributedTitle = mutStr

        return menuItemHeader
    }

    class func getPasswordHistoryMenu(item: Node) -> NSMenu? {
        let changeHistory = PasswordHistoryProcessor.getHistory(item: item)

        guard !changeHistory.isEmpty else {
            return nil
        }

        let ret = NSMenu(title: "")
        ret.autoenablesItems = false

        let ret1 = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        if let image = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: "") {
            let large = image.withSymbolConfiguration(NSImage.SymbolConfiguration(scale: .large))
            ret1.image = large
        }

        ret.items.append(ret1)
        ret.items.append(getHeaderMenuItem(NSLocalizedString("password_history_previous_passwords", comment: "Previous Passwords"), headline: true))
        ret.items.append(NSMenuItem.separator())

        for changeEvent in changeHistory {
            let mod = changeEvent.0
            let pw = changeEvent.1

            let fmt: String
            if changeEvent == changeHistory.first!, changeHistory.count > 1 {
                fmt = NSLocalizedString("password_history_this_password_was_used_until_most_recent_fmt", comment: "Most Recent (Used until %@)")
            } else if changeEvent == changeHistory.last!, changeHistory.count > 1 {
                fmt = NSLocalizedString("password_history_this_password_was_used_until_oldest_fmt", comment: "Oldest (Used until %@)")
            } else {
                fmt = NSLocalizedString("password_history_this_password_was_used_until_fmt", comment: "Used until %@")
            }

            let header = String(format: fmt, (mod as NSDate).friendlyDateTimeStringPrecise)
            ret.items.append(getHeaderMenuItem(header))

            let menuItem = NSMenuItem(title: pw, action: #selector(PasswordHistoryHelper.copyHistoricalPassword(sender:)), keyEquivalent: "")
            menuItem.target = self

            ret.items.append(menuItem)
            ret.items.append(NSMenuItem.separator())
        }

        return ret
    }

    @objc class func copyHistoricalPassword(sender: Any?) {
        guard let menuItem = sender as? NSMenuItem else {
            
            return
        }

        ClipboardManager.sharedInstance().copyConcealedString(menuItem.title)
    }
}
