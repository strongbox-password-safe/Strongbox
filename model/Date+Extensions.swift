//
//  Date+Extensions.swift
//  Strongbox
//
//  Created by Strongbox on 04/01/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

// iso8601withFractionalSeconds always at 'Zulu' i.e. GMT+00:00 and always fixed string length of 24

public extension ISO8601DateFormatter {
    static let Iso8601withFractionalSecondsCharacterCount = 24

    convenience init(_ formatOptions: Options) {
        self.init()
        self.formatOptions = formatOptions
    }
}

public extension Formatter {
    static let iso8601withFractionalSeconds = ISO8601DateFormatter([.withInternetDateTime, .withFractionalSeconds])
}

public extension Date {
    var iso8601withFractionalSeconds: String { Formatter.iso8601withFractionalSeconds.string(from: self) }
}

public extension String {
    var iso8601withFractionalSeconds: Date? { Formatter.iso8601withFractionalSeconds.date(from: self) }
}

public extension JSONDecoder.DateDecodingStrategy {
    static let iso8601withFractionalSeconds = custom {
        let container = try $0.singleValueContainer()
        let string = try container.decode(String.self)
        guard let date = Formatter.iso8601withFractionalSeconds.date(from: string) else {
            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "Invalid date: " + string)
        }
        return date
    }
}

public extension JSONEncoder.DateEncodingStrategy {
    static let iso8601withFractionalSeconds = custom {
        var container = $1.singleValueContainer()
        try container.encode(Formatter.iso8601withFractionalSeconds.string(from: $0))
    }
}



public extension Date {
    static func randomDate(range: Int) -> Date {
        
        let interval = Date().timeIntervalSince1970
        
        
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



public extension Date {
    func isEqualToDateWithinEpsilon(_ other: Date) -> Bool {
        (self as NSDate).isEqualToDate(withinEpsilon: other)
    }
}
