//
//  Logging.swift
//  MacBox
//
//  Created by Strongbox on 26/08/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Foundation

extension Date {
   func getFormattedDate(format: String) -> String { // TODO: perf
        let dateformat = DateFormatter()
        dateformat.dateFormat = format
        return dateformat.string(from: self)
    }
}

class Logging {
    static func warn(_ message: String) {
        log("WARNWARN" + message)
    }
    
    static func log(_ message: String) {
        let date = Date()
        let format = date.getFormattedDate(format: "yyyy-MM-dd HH:mm:ss.SSSSSSZ") 

        print("\(format) \(message)");
    }
}
