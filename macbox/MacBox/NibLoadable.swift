//
//  NibLoadable.swift
//  MacBox
//
//  Created by Strongbox on 07/02/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa
import Foundation

protocol NibLoadable {
    static var nibName: String? { get }
    static func createFromNib(in bundle: Bundle) -> Self?
}

extension NibLoadable where Self: NSView {
    static var nibName: String? {
        String(describing: Self.self)
    }

    static func createFromNib(in bundle: Bundle = Bundle.main) -> Self? {
        guard let nibName else { return nil }
        var topLevelArray: NSArray?
        bundle.loadNibNamed(NSNib.Name(nibName), owner: self, topLevelObjects: &topLevelArray)
        guard let results = topLevelArray else { return nil }
        let views = [Any](results).filter { $0 is Self }
        return views.last as? Self
    }
}
