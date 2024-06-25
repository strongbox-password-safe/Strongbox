//
//  TextFieldFocused.swift
//  Strongbox
//
//  Created by Strongbox on 28/12/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Foundation
import SwiftUI

private struct TextFieldFocused: ViewModifier {
    @FocusState private var focused: Bool

    init() {
        focused = false
    }

    func body(content: Content) -> some View {
        content
            .focused($focused)
            .onAppear {
                focused = true
            }
    }
}

extension View {
    @ViewBuilder
    func focused() -> some View {
        modifier(TextFieldFocused())
    }
}
