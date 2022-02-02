//
//  Date+Extensions.swift
//  MacBox
//
//  Created by Strongbox on 13/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Foundation

extension Date {
    static func randomDate(range: Int) -> Date {
        // Get the interval for the current date
        let interval = Date().timeIntervalSince1970
        // There are 86,400 milliseconds in a day (ignoring leap dates)
        // Multiply the 86,400 milliseconds against the valid range of days
        let intervalRange = Double(86400 * range)
        
        let random = Double(arc4random_uniform(UInt32(intervalRange)) + 1)
        
        
        let newInterval = interval + (random - (intervalRange / 2.0))
        
        return Date(timeIntervalSince1970: newInterval)
    }

    func addMonth(n: Int) -> Date {
        let cal = NSCalendar.current
        return cal.date(byAdding: .month, value: n, to: self)!
    }

    func addDay(n: Int) -> Date {
        let cal = NSCalendar.current
        return cal.date(byAdding: .day, value: n, to: self)!
    }

    func addSec(n: Int) -> Date {
        let cal = NSCalendar.current
        return cal.date(byAdding: .second, value: n, to: self)!
    }
}
