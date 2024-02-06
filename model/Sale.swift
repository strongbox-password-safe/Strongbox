//
//  Sale.swift
//  Strongbox
//
//  Created by Strongbox on 08/01/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

// import Foundation

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
    init(start: Date, end: Date, title: String? = nil, promoCode: String? = nil, showToExistingSubscribers: Bool = false) {
        self.start = start
        self.end = end
        self.title = title
        self.promoCode = promoCode
        self.showToExistingSubscribers = showToExistingSubscribers
    }

    
    
    

    @objc
    static var schedule: [Sale] = [
        Sale(startLondonNoonTimeInclusive: "2021-11-26", endLondonNoonTimeExclusive: "2021-11-30"), 
        Sale(startLondonNoonTimeInclusive: "2021-12-24", endLondonNoonTimeExclusive: "2021-12-27"), 

        

        Sale(startLondonNoonTimeInclusive: "2022-03-17", endLondonNoonTimeExclusive: "2022-03-21"), 
        Sale(startLondonNoonTimeInclusive: "2022-06-03", endLondonNoonTimeExclusive: "2022-06-07"), 
        Sale(startLondonNoonTimeInclusive: "2022-09-02", endLondonNoonTimeExclusive: "2022-09-05"), 
        Sale(startLondonNoonTimeInclusive: "2022-11-25", endLondonNoonTimeExclusive: "2022-11-29"), 

        

        Sale(startLondonNoonTimeInclusive: "2023-03-17", endLondonNoonTimeExclusive: "2023-03-20"), 
        Sale(startLondonNoonTimeInclusive: "2023-03-17", endLondonNoonTimeExclusive: "2023-03-20"), 
        Sale(startLondonNoonTimeInclusive: "2023-07-01", endLondonNoonTimeExclusive: "2023-07-05"), 
        Sale(startLondonNoonTimeInclusive: "2023-11-24", endLondonNoonTimeExclusive: "2023-11-28"), 
        Sale(startLondonNoonTimeInclusive: "2023-12-24", endLondonNoonTimeExclusive: "2023-12-27"), 

        

        Sale(startLondonNoonTimeInclusive: "2024-03-15", endLondonNoonTimeExclusive: "2024-03-18", title: "☘️ St. Patrick's Day Special ☘️", promoCode: "IRE24"),
        Sale(startLondonNoonTimeInclusive: "2024-05-31", endLondonNoonTimeExclusive: "2024-06-04", title: "June Special", promoCode: "JUNE24"),
        Sale(startLondonNoonTimeInclusive: "2024-08-30", endLondonNoonTimeExclusive: "2024-09-03", title: "September Special", promoCode: "SEPT24"),
        Sale(startLondonNoonTimeInclusive: "2024-11-29", endLondonNoonTimeExclusive: "2024-12-03", title: "Black Friday Special", promoCode: "BF24", showToExistingSubscribers: true),

        

        Sale(startLondonNoonTimeInclusive: "2025-03-14", endLondonNoonTimeExclusive: "2025-03-18", title: "☘️ St. Patrick's Day Special ☘️", promoCode: "IRE25"),
    ]
}
