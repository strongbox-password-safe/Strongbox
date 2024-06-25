//
//  PasswordConcealRevealTextField.swift
//  MacBox
//
//  Created by Strongbox on 12/10/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import SwiftUI

struct PasswordConcealRevealTextField: View {
    @Binding var text: String
    @Binding var isSecure: Bool
    var titleKey: String

    var body: some View {
        Group {
            if isSecure {
                SecureField(titleKey, text: $text)
            } else {
                TextField(titleKey, text: $text)
            }
        }
        .foregroundColor(.primary)
        .controlSize(.large)
        .textFieldStyle(.roundedBorder)
        .animation(.easeInOut(duration: 0.2), value: isSecure)
        .overlay(alignment: .trailing) {
            Button(action: {
                isSecure.toggle()
            }, label: {
                Image(systemName: !isSecure ? "eye.slash" : "eye")
            })
            .buttonStyle(.borderless)
            .padding([.trailing], 6)
        }
    }
}


