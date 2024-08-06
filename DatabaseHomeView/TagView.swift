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
    var useEasyReadFont: Bool = false

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "tag")
                .font(.subheadline)

            Text(title)
                .lineLimit(1)
                .font(useEasyReadFont ? .custom("Menlo", size: 16) : .body)
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
    VStack {
        TagView(title: "Test")
        TagView(title: "Test with a long title")
        TagView(title: "Super Word")
        TagView(title: "Testing #1")
    }
}
