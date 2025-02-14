//
//  TagView.swift
//  Strongbox
//
//  Created by Strongbox on 27/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation
import SwiftUI

struct TagView: View {
    var title: String
    var font: Font

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "tag")
                .font(.subheadline)

            Text(title)
                .lineLimit(1)
                .font(font)
        }
        .padding(.trailing, 10)
        .padding(.leading, 6)
        .padding(.vertical, 4)
        .foregroundStyle(.white)
        .background(.blue)
        .clipShape(Capsule())
        .shadow(radius: 1)
    }
}

#Preview {
    #if os(iOS)
        let font2 = Font(FontManager.sharedInstance().easyReadFont)
    #else
        let font2 = Font(FontManager.shared.easyReadFont)
    #endif

    return VStack {
        TagView(title: "Test", font: font2)
        TagView(title: "Test with a long title", font: font2)
        TagView(title: "Super Word", font: font2)
        TagView(title: "Testing #1", font: font2)
    }
}
