//
//  ConcealedFieldDetailView.swift
//  Strongbox
//
//  Created by Strongbox on 15/12/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct ConcealedFieldDetailView: View {
    var value: String
    var colorBlind: Bool

    @EnvironmentObject
    var model: WatchAppModel

    @Environment(\.colorScheme)
    var colorScheme

    var darkMode: Bool {
        colorScheme == .dark
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                let coloredString = SwiftStringColourifier.getSwiftUIColoredString(value, darkMode: darkMode, colorBlind: colorBlind)
                let view1 = Text(coloredString)
                    .font(Font.system(size: 18).monospaced())
                    .padding()

                let view2 = ConcealedFieldValueGrid(value: value, colorBlind: colorBlind)

                if model.settings.pro {
                    view1
                    view2
                } else {
                    VStack {
                        ProBadge()

                        view1.blur(radius: 4)
                        view2.blur(radius: 6)
                    }
                }
            }
        }
    }
}

#Preview {
    ConcealedFieldDetailView(value: "X_3CxJi$44GJa*LJ^K4GJa*LJ^K", colorBlind: true)
        .environmentObject(WatchAppModel())
}
