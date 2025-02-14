//
//  LargeTextDisplayView.swift
//  Strongbox
//
//  Created by Strongbox on 30/03/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct LargeTextViewCharacter: View {
    let character: String
    let index: Int
    let color: Color
    let font: Font

    @Environment(\.colorScheme) var colorScheme

    var darkMode: Bool {
        colorScheme == .dark
    }

    var body: some View {
        let dark = darkMode ? Color(UIColor(white: 0.25, alpha: 1.0)) : Color(UIColor(white: 0.77, alpha: 1.0))
        let light = darkMode ? Color(UIColor(white: 0.35, alpha: 1.0)) : Color(UIColor(white: 0.92, alpha: 1.0))

        let bgColor = index % 2 == 0 ? dark : light

        ZStack {
            Rectangle()
                .fill(bgColor)

            VStack(spacing: -1) {
                Text(character)
                    .font(font)
                    .foregroundColor(color)

                Text(String(index + 1))
                    .foregroundColor(.secondary)
                    .font(Font.system(size: 10).monospacedDigit())
            }
            .padding(.bottom, 4)
        }
    }
}

struct LargeTextDisplayView: View {
    let text: String
    let font: Font
    let colorize: Bool
    let colorBlind: Bool
    let onTapped: () -> Void

    let columns: [GridItem] = [GridItem(.adaptive(minimum: 40), spacing: 1)]

    @Environment(\.colorScheme) var colorScheme

    var darkMode: Bool {
        colorScheme == .dark
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 1) {
                let chars = Array(text)
                ForEach(Array(chars.enumerated()), id: \.offset) { index, char in
                    let character = String(char)
                    let color = colorize ? SwiftStringColourifier.getSwiftUIColor(for: character, darkMode: darkMode, colorBlind: colorBlind) : Color.primary

                    let view = LargeTextViewCharacter(character: character,
                                                      index: index,
                                                      color: color,
                                                      font: font)

                    if index == chars.count - 1 { 
                        if #available(iOS 16.0, *) {
                            view.clipShape(
                                .rect(topLeadingRadius: 0, bottomLeadingRadius: 0,
                                      bottomTrailingRadius: 2, topTrailingRadius: 0)
                            )
                        } else {
                            view
                        }
                    } else {
                        view
                    }
                }
            }
            .cornerRadius(2)
        }
        .gesture(TapGesture(count: 1).onEnded { _ in
            onTapped()
        })
    }
}

#Preview {
    ZStack(alignment: .center) {
        Rectangle().fill(Color(UIColor(white: 0.12, alpha: 1.0))) 

        LargeTextDisplayView(text: "KchY+VY=*=Em$h9G$a*4BCfG-xUa+vkkCzXbHLKchY+VY=*=Em$h9G$a*4BCfG-xUa+vkkCzXbHLKchY+VY=*=Em$h9G$a*4BCfG-xUa+vkkCzXbHL",
                             font: Font.system(size: 32).monospaced(),
                             colorize: true,
                             colorBlind: false,
                             onTapped: {})
            .padding(40)
    }
}
