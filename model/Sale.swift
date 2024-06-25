//
//  Sale.swift
//  Strongbox
//
//  Created by Strongbox on 08/01/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

@objc
class Sale: NSObject {
    @objc var start: Date
    @objc var end: Date
    @objc var title: String?
    @objc var promoCode: String?
    @objc var showToExistingSubscribers: Bool

    @objc
    convenience init(startLondonNoonTimeInclusive: String, endLondonNoonTimeExclusive: String, title: String, promoCode: String, showToExistingSubscribers _: Bool = false) {
        self.init(startLondonNoonTimeInclusive: startLondonNoonTimeInclusive, endLondonNoonTimeExclusive: endLondonNoonTimeExclusive)
        self.title = title
        self.promoCode = promoCode
    }

    @objc
    convenience init(startLondonNoonTimeInclusive: String, endLondonNoonTimeExclusive: String) {
        let start = NSDate.fromYYYY_MM_DD_London_Noon_Time_String(startLondonNoonTimeInclusive)
        let end = NSDate.fromYYYY_MM_DD_London_Noon_Time_String(endLondonNoonTimeExclusive)

        self.init(start: start as Date, end: end as Date)
    }

    @objc
    convenience init(_ startStr: String, _ endStr: String, title: String? = nil, promoCode: String? = nil) {
        let start = NSDate.fromYYYY_MM_DDString(startStr)
        let end = NSDate.fromYYYY_MM_DDString(endStr)

        self.init(start: start as Date, end: end as Date, title: title, promoCode: promoCode)
    }

    @objc
    init(start: Date, end: Date, title: String? = nil, promoCode: String? = nil, showToExistingSubscribers: Bool = false) {
        self.start = start
        self.end = end
        self.title = title
        self.promoCode = promoCode
        self.showToExistingSubscribers = showToExistingSubscribers
    }

    
    

    @objc
    static var schedule: [Sale] = [
        Sale("2021-11-26", "2021-11-30"), 
        Sale("2021-12-24", "2021-12-27"), 

        

        Sale("2022-03-17", "2022-03-21"), 
        Sale("2022-06-03", "2022-06-07"), 
        Sale("2022-09-02", "2022-09-05"), 
        Sale("2022-11-25", "2022-11-29"), 

        

        Sale("2023-03-17", "2023-03-20"), 
        Sale("2023-03-17", "2023-03-20"), 
        Sale("2023-07-01", "2023-07-05"), 
        Sale("2023-11-24", "2023-11-28"), 
        Sale("2023-12-24", "2023-12-27"), 

        

        Sale("2024-03-15", "2024-03-18", title: "☘️ St. Patrick's Day Special ☘️", promoCode: "IRE24"),
        Sale("2024-05-31", "2024-06-04", title: "June Special", promoCode: "JUNE24"),
        Sale("2024-11-29", "2024-12-03", title: "Black Friday Special", promoCode: "BF24"),

        

        Sale("2025-03-14", "2025-03-18", title: "☘️ St. Patrick's Day Special ☘️", promoCode: "IRE25"),
        Sale("2025-07-04", "2025-07-08", title: "July 4th Special", promoCode: "JULY425"),
        Sale("2025-11-28", "2025-12-02", title: "Black Friday Special", promoCode: "BF25"),
    ]
}
