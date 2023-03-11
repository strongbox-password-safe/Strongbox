//
//  PasswordHistoryHelper.swift
//  MacBox
//
//  Created by Strongbox on 06/02/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Foundation

class PasswordHistoryHelper {
    class func getHeaderMenuItem ( _ title : String, headline: Bool = false ) -> NSMenuItem {
        let menuItemHeader = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        menuItemHeader.isEnabled = false
        menuItemHeader.target = self
        
        let attributes: [NSAttributedString.Key: Any] = [.font: headline ? FontManager.shared.headlineFont : FontManager.shared.bodyFont,
                                                         .foregroundColor: NSColor.secondaryLabelColor]
        
        let mutStr = NSMutableAttributedString(string: title, attributes: attributes)
        menuItemHeader.attributedTitle = mutStr
        
        return menuItemHeader
    }
    
    class func getPasswordHistoryMenu( item : Node ) -> NSMenu? {
        guard let history = item.fields.keePassHistory as? [Node],
              item.fields.keePassHistory.count > 0 else {
            return nil
        }
        
        let ret = NSMenu(title: "")
        ret.autoenablesItems = false
        
        let ret1 = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        if #available(macOS 11.0, *) {
            if let image = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: "") {
                let large = image.withSymbolConfiguration(NSImage.SymbolConfiguration(scale: .large))
                ret1.image = large
            }
        } else {
            return nil
        }

        ret.items.append(ret1)
        ret.items.append(getHeaderMenuItem( NSLocalizedString("password_history_previous_passwords", comment: "Previous Passwords"), headline: true ))
        ret.items.append(NSMenuItem.separator())
        
        var mod = item.fields.modified as NSDate?
        var currentPassword = item.fields.password
        var foundHistory = false
        for hist in history.reversed() {
            let pw = hist.fields.password
            if pw.localizedCompare(currentPassword) == .orderedSame {
                continue
            }
            
            if let mod { 
                let fmt =  NSLocalizedString("password_history_this_password_was_used_until_fmt", comment: "Used until %@")
                let header = String(format: fmt, mod.friendlyDateTimeString)
                ret.items.append(getHeaderMenuItem( header ))
            }
            
            let menuItem = NSMenuItem(title: pw, action: #selector(PasswordHistoryHelper.copyHistoricalPassword(sender:)), keyEquivalent: "")
            menuItem.target = self
            
            ret.items.append(menuItem)
            ret.items.append(NSMenuItem.separator())
            
            mod = hist.fields.modified as NSDate?;
            currentPassword = pw;
            foundHistory = true
        }
        
        return foundHistory ? ret : nil
    }
    
    @objc class func copyHistoricalPassword ( sender : Any? ) {
        guard let menuItem = sender as? NSMenuItem else {
            
            return
        }
        
        ClipboardManager.sharedInstance().copyConcealedString(menuItem.title)
    }
}
