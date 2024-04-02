//
//  LargeTextDisplayView.swift
//  Strongbox
//
//  Created by Strongbox on 30/03/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct LargeTextDisplayView: View {
    let text: String
    let font: Font
    let colorMapper: (String) -> Color
    let onTapped: () -> Void

    let columns: [GridItem] = [GridItem(.adaptive(minimum: 32))]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                let chars = Array(text)
                ForEach(Array(chars.enumerated()), id: \.offset) { index, char in
                    let character = String(char)

                    LargeTextViewCharacter(character: character,
                                           index: index,
                                           color: colorMapper(character),
                                           font: font)
                }
            }
        }
        .gesture(TapGesture(count: 1).onEnded { _ in
            onTapped()
        })
    }
}

#Preview {
    LargeTextDisplayView(text: "KchY+VY=*=Em$h9G$a*4BCfG-xUa+vkkCzXbHLKchY+VY=*=Em$h9G$a*4BCfG-xUa+vkkCzXbHLKchY+VY=*=Em$h9G$a*4BCfG-xUa+vkkCzXbHL", font: Font.custom("Menlo", size: 32), colorMapper: { _ in
        .blue
    }) {}
}
