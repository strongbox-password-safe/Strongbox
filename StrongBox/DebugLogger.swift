//
//  DebugLogger.swift
//  Strongbox
//
//  Created by Strongbox on 06/01/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import UIKit

@objc
enum DebugLineCategory: Int {
    case debug
    case info
    case error
    case warn
}

@objc
class DebugLine: NSObject {
    @objc var date: Date
    @objc var line: String
    @objc var category: DebugLineCategory

    init(date: Date, line: String, category: DebugLineCategory) {
        self.date = date
        self.line = line
        self.category = category

        super.init()
    }
}

extension Notification.Name {
    static let debugLoggerLinesUpdated = Notification.Name("debugLoggerLinesUpdated")
}

@objc
class DebugLogger: NSObject {
    static let Capacity = 8192
    static var lines: ConcurrentCircularBuffer<DebugLine> = ConcurrentCircularBuffer(capacity: UInt(Capacity))

    @objc
    static func debug(_ line: String) {
        #if DEBUG
            NSLog("🐞 [DebugLogger] - DEBUG - \(line)")
            lines.add(DebugLine(date: Date(), line: line, category: .debug))
            NotificationCenter.default.post(name: .debugLoggerLinesUpdated, object: nil)
        #endif
    }

    @objc
    static func info(_ line: String) {
        #if DEBUG
            NSLog("🟢 [DebugLogger] - INFO - \(line)")
            lines.add(DebugLine(date: Date(), line: line, category: .info))
            NotificationCenter.default.post(name: .debugLoggerLinesUpdated, object: nil)
        #endif
    }

    @objc
    static func warn(_ line: String) {
        #if DEBUG
            NSLog("⚠️ [DebugLogger] - WARN - \(line)")
            lines.add(DebugLine(date: Date(), line: line, category: .warn))
            NotificationCenter.default.post(name: .debugLoggerLinesUpdated, object: nil)
        #endif
    }

    @objc
    static func error(_ line: String) {
        #if DEBUG
            NSLog("🔴 [DebugLogger] - ERROR - \(line)")
            lines.add(DebugLine(date: Date(), line: line, category: .error))
            NotificationCenter.default.post(name: .debugLoggerLinesUpdated, object: nil)
        #endif
    }

    @objc
    static var snapshot: [DebugLine] {
        lines.allObjects()
    }
}
