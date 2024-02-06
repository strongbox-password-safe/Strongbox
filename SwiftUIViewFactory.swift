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
    @objc static func makeImportResultViewController(messages: [ImportMessage] = [],
                                                     dismissHandler: @escaping ((_ cancel: Bool) -> Void)) -> UIViewController
    {
        let hostingController = UIHostingController(rootView: ImportResultView(dismiss: dismissHandler, messages: messages))

        return hostingController
    }

    @objc static func makeSaleOfferViewController(sale: Sale,
                                                  existingSubscriber: Bool,
                                                  redeemHandler: @escaping (() -> Void),
                                                  onLifetimeHandler: @escaping (() -> Void),
                                                  dismissHandler: @escaping (() -> Void)) -> UIViewController
    {
        let hostingController = UIHostingController(rootView: SaleOfferView(dismiss: dismissHandler, onLifetime: onLifetimeHandler, redeem: redeemHandler, sale: sale, existingSubscriber: existingSubscriber))

        return hostingController
    }

    @objc static func makeWiFiSyncPasscodeViewController(_ server: WiFiSyncServerConfig, onDone: @escaping ((_ server: WiFiSyncServerConfig, _ pinCode: String?) -> Void)) -> UIViewController {
        let hostingController = UIHostingController(rootView: PasscodeEntryView(server: server, onDone: onDone))

        return hostingController
    }
}
