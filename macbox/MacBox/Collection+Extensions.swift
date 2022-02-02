//
//  Collection+Extensions.swift
//  MacBox
//
//  Created by Strongbox on 25/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Foundation

extension Collection where Indices.Iterator.Element == Index {
    // https://stackoverflow.com/a/30593673/3963806

    subscript(safe index: Index) -> Iterator.Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
