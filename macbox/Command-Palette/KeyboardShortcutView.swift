//
//  KeyboardShortcutView.swift
//  MacBox
//
//  Created by Strongbox on 21/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation
import SwiftUI

struct KeyboardShortcutView: View {
    var shortcut: String
    var title: String

    var body: some View {
        HStack(spacing: 4) {
            HStack(spacing: 2) {
                Text(shortcut)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerSize: CGSize(width: 5, height: 5))
                    .foregroundColor(.blue)
                    .shadow(radius: 1)
            }

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
