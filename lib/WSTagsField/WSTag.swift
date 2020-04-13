//
//  WSTag.swift
//  Whitesmith
//
//  Created by Ricardo Pereira on 12/05/16.
//  Copyright © 2016 Whitesmith. All rights reserved.
//

import Foundation

public struct WSTag: Hashable {

    public let text: String
    public let context: AnyHashable?

    public init(_ text: String, context: AnyHashable? = nil) {
        self.text = text
        self.context = context
    }

    public func equals(_ other: WSTag) -> Bool {
        return self.text == other.text && self.context == other.context
    }

}

public func == (lhs: WSTag, rhs: WSTag) -> Bool {
    return lhs.equals(rhs)
}
