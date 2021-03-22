//
//  SwiftUIViewFactory.swift
//  MacBox
//
//  Created by Strongbox on 12/03/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Foundation
import SwiftUI

@available(OSX 10.15, *)
class SwiftUIViewFactory: NSObject {
  @objc static func makeSwiftUIView(dismissHandler: @escaping (() -> Void)) -> NSViewController? {
    return SwiftUIController(coder: NSCoder())
  }
}
