//
//  Collection+Extensions.swift
//  MacBox
//
//  Created by Strongbox on 25/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Foundation

extension Collection where Indices.Iterator.Element == Index {
    

    subscript(safe index: Index) -> Iterator.Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension Array {
    func splitInPairs() -> [(Element?, Element?)] {
        var foo = stride(from: 0, to: count, by: 2).map { self[$0] as Element? }
        var bar = stride(from: 1, to: count, by: 2).map { self[$0] as Element? }

        if foo.count < bar.count {
            foo.append(nil)
        } else if bar.count < foo.count {
            bar.append(nil)
        }

        let zipped = zip(foo, bar)

        let arr = zipped.map { pair in
            pair
        }

        return arr
    }
}
