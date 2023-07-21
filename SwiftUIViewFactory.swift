//
//  SwiftUIViewFactory.swift
//  Strongbox
//
//  Created by Strongbox on 05/07/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Foundation
import SwiftUI

class SwiftUIViewFactory: NSObject {
    @objc static func makeImportResultViewController(messages : [ImportMessage] = [],
                                                     dismissHandler: @escaping (( _ cancel : Bool ) -> Void)) -> UIViewController {
        let hostingController = UIHostingController(rootView: ImportResultView(dismiss: dismissHandler, messages: messages))
        
        return hostingController
    }

    @objc static func makeSaleOfferViewController(saleEndDate : Date,
                                                       existingSubscriber : Bool,
                                                       redeemHandler: @escaping (() -> Void),
                                                       onLifetimeHandler: @escaping (() -> Void),
                                                       dismissHandler: @escaping (() -> Void) ) -> UIViewController {
        let hostingController = UIHostingController(rootView: SaleOfferView(dismiss: dismissHandler, onLifetime: onLifetimeHandler, redeem: redeemHandler, saleEndDate: saleEndDate, existingSubscriber: existingSubscriber))
        
        return hostingController
    }
}
