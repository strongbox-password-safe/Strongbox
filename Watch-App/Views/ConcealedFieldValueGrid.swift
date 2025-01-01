//
//  ConcealedFieldValueGrid.swift
//  Strongbox
//
//  Created by Strongbox on 15/12/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct ConcealedFieldValueGrid: View {
    var value: String
    var colorBlind: Bool

    var body: some View {
        LargeTextDisplayView(text: value,
                             font: Font.system(size: 32).monospaced(),
                             colorize: true,
                             colorBlind: colorBlind,
                             onTapped: {})
    }
}

#Preview {
    ConcealedFieldValueGrid(value: "Testing $the Large% ^Text View* 123 #Test", colorBlind: true)
}
