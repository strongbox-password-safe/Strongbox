//
//  SwiftUIExpiryHelper.swift
//  Strongbox
//
//  Created by Strongbox on 10/07/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Foundation
import SwiftUI

@available(iOS 16.0, *)
@objc
public class SwiftUIExpiryHelper: NSObject {
    @objc
    public class func foo(cell: EditDateCell, expiry: Date) {
        let config = UIHostingConfiguration {
            NewExpiryCellView(date: expiry)
        }
        cell.contentConfiguration = config
    }
}
