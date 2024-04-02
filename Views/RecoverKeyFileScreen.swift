//
//  RecoverKeyFileScreen.swift
//  MacBox
//
//  Created by Strongbox on 27/03/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct RecoverKeyFileScreen: View {
    var verifyHash: ((_ codes: String, _ hash: String) -> Bool)!
    var validateCodes: ((_ codes: String) -> Bool)!
    var onRecover: ((_ codes: String) -> Void)!
    var onDismiss: (() -> Void)!

    @Environment(\.colorScheme) var colorScheme: ColorScheme

    @State
    var codes: String = ""

    @State
    var hash: String = ""

    var codesAreValid: Bool {
        validateCodes(codes)
    }

    var hashIsValid: Bool {
        hash.count == 0 || verifyHash(codes, hash)
    }

    var body: some View {
        let mainBody = VStack(alignment: .leading, spacing: 20) {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "key")
                        .foregroundColor(.blue)
                        .font(.largeTitle)

                    Text("recover_key_file_title")
                        .font(.largeTitle)
                }
                .frame(maxWidth: .infinity)

                Text("recover_key_file_enter_codes")
            }

            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("recover_key_file_data_hex_codes").font(.headline)

                    let textEditor = TextEditor(text: $codes)
                        .foregroundColor(colorScheme == .dark ? .green : Color.primary)
                        .lineLimit(2)
                        .frame(height: 100)
                    #if os(macOS)
                        textEditor
                            .font(.system(.title2, design: .monospaced))
                            .cornerRadius(5)
                    #else
                        textEditor
                            .border(.gray)
                            .font(.system(.body, design: .monospaced))
                    #endif
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("recover_key_file_hash_optional_title").font(.headline)

                    let hashTextField = TextField("key_file_hash_title", text: $hash)

                    #if os(macOS)
                        hashTextField
                            .font(.system(.title2, design: .monospaced))
                            .cornerRadius(5)
                    #else
                        hashTextField
                            .padding(4)
                            .border(.gray)
                            .font(.system(.body, design: .monospaced))
                    #endif

                    if hash.count > 0 {
                        if hashIsValid {
                            HStack(alignment: .center, spacing: 4) {
                                Image(systemName: "checkmark.circle")
                                    .font(.headline)
                                    .foregroundColor(.green)

                                Text("recover_key_file_valid_hash")
                                    .font(.headline)
                                    .foregroundColor(colorScheme == .dark ? .green : Color.primary)
                            }
                        } else {
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Image(systemName: "x.circle")
                                    .font(.headline)
                                    .foregroundColor(.red)

                                Text("recover_key_file_invalid_hash")
                                    .font(.headline)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }

            let recoverBtn = Button(action: {
                onRecover(codes)
            }, label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")

                    Text("recover_key_file_title")
                }
            })
            .frame(maxWidth: .infinity)
            .disabled(!codesAreValid || !hashIsValid)

            #if os(macOS)
                recoverBtn
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            #else
                recoverBtn
            #endif

            #if os(iOS)
                Button {
                    onDismiss()
                } label: {
                    Text("generic_cancel")
                }
                .frame(minWidth: 0, maxWidth: .infinity)
            #endif
        }

        #if os(macOS)
            return mainBody
                .frame(width: 500)
                .padding(20)
                .fixedSize()
        #else
            return mainBody
                .padding()
        #endif
    }
}

#Preview {
    RecoverKeyFileScreen(verifyHash: { _, _ in
        false
    }, validateCodes: { _ in
        true
    },
    codes: "9A3A4FE1 96E34067 09CF4758 31BD3640\nA0DC21FA F83F1C91 FBB660FB C5FE40C1",
    hash: "E8CACD93")
}
