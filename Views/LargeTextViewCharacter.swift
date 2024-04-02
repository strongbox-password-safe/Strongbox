//
//  LargeTextViewCharacter.swift
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

    var body: some View {
        VStack(spacing: 4) {


            Text(character)
                .font(font)

                .foregroundColor(color)


            Text(String(index + 1))
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
}

#Preview {
    LargeTextViewCharacter(character: "_", index: 1, color: .blue, font: .custom("Menlo", size: 32))
}
