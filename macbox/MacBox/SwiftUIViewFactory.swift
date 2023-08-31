//
//  SwiftUIViewFactory.swift
//  MacBox
//
//  Created by Strongbox on 04/07/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Foundation
import SwiftUI

// class StrongboxHostingController<Content> : NSHostingController<Content> where Content : View {
//    override func viewDidAppear() {
//        super.viewDidAppear()
//
//        view.window?.center()



class SwiftUIViewFactory: NSObject {
    @objc static func makeImportResultViewController(messages: [ImportMessage] = [], dismissHandler: @escaping ((_ cancel: Bool) -> Void)) -> NSViewController {
        let hostingController = NSHostingController(rootView: ImportResultView(dismiss: dismissHandler, messages: messages))

        

        hostingController.preferredContentSize = NSSize(width: 400, height: 400)
        if #available(macOS 13.0, *) {
            hostingController.sizingOptions = .preferredContentSize
        }

        return hostingController
    }

    @objc static func makeSaleOfferViewController(saleEndDate: Date,
                                                  existingSubscriber: Bool,
                                                  redeemHandler: @escaping (() -> Void),
                                                  onLifetimeHandler: @escaping (() -> Void),
                                                  dismissHandler: @escaping (() -> Void)) -> NSViewController
    {
        let hostingController = NSHostingController(rootView: SaleOfferView(dismiss: dismissHandler,
                                                                            onLifetime: onLifetimeHandler,
                                                                            redeem: redeemHandler,
                                                                            saleEndDate: saleEndDate,
                                                                            existingSubscriber: existingSubscriber))

        hostingController.preferredContentSize = NSSize(width: 400, height: 400)
        if #available(macOS 13.0, *) {
            hostingController.sizingOptions = .preferredContentSize
        }

        hostingController.title = NSLocalizedString("sale_view_regular_title", comment: "Sale Now On")

        return hostingController
    }
}
