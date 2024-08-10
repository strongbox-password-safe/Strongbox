//
//  SwiftSBLog.swift
//  Strongbox
//
//  Created by Strongbox on 03/08/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation

#if !DEBUG
    func swlog(_: String, _: Any...) {}
#else
    public func swlog(file _: String = #file, function: String = #function, line _: Int = #line, column _: Int = #column, _ log: String, _ args: Any?...) {
        var msg: String
        if args.isEmpty {
            msg = log
        } else {
            msg = String(format: log, args)
        }



        let threadId = Thread.isMainThread ? "M" : "N"
        NSLog("\(threadId)[\(Date.now.iso8601withFractionalSeconds)] \(function): %@", msg)
        
    }
#endif
