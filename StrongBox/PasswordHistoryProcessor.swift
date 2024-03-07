//
//  PasswordHistoryProcessor.swift
//  Strongbox
//
//  Created by Strongbox on 16/02/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation

@objc
public class PasswordChangeEvent: NSObject { 
    @objc var password: String
    @objc var wasUsedUntil: Date

    init(password: String, wasUsedUntil: Date) {
        self.password = password
        self.wasUsedUntil = wasUsedUntil
    }
}

@objc
public class PasswordHistoryProcessor: NSObject {
    class func getFullPasswordHistoryList(node: Node) -> [(Date, String)] {
        guard let history = node.fields.keePassHistory as? [Node], history.count > 0 else {
            return []
        }

        var allPasswords: [(Date, String)] = []

        for hist in history {
            guard let mod = hist.fields.modified else {
                continue
            }

            
            allPasswords.append((mod, hist.fields.password))
        }

        if let mod = node.fields.modified {
            
            allPasswords.append((mod, node.fields.password))
        }

        

        let sorted = allPasswords.sorted { a, b in
            a.0.compare(b.0) == .orderedAscending
        }

        

        return sorted
    }

    public class func getHistory(item: Node) -> [(Date, String)] { 
        

        
        
        
        
        
        

        let allPasswords = getFullPasswordHistoryList(node: item)

        guard var currentPassword = allPasswords.first?.1 else {
            return [] 
        }

        var ret: [(Date, String)] = []

        for current in allPasswords {
            let pw = current.1

            guard pw.localizedCompare(currentPassword) != .orderedSame else { 
                continue
            }

            let mod = current.0

            

            ret.append((mod, currentPassword))

            currentPassword = pw
        }

        return ret.reversed() 
    }

    @objc
    public class func getHistoryChangeEvents(item: Node) -> [PasswordChangeEvent] {
        let hist = getHistory(item: item)

        return hist.map { PasswordChangeEvent(password: $0.1, wasUsedUntil: $0.0) }
    }
}
