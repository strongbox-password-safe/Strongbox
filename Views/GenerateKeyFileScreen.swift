//
//  GenerateKeyFileScreen.swift
//  MacBox
//
//  Created by Strongbox on 26/03/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct GenerateKeyFileScreen: View {
    var keyFile: KeyFile!
    var onPrint: (() -> Void)!
    var onSave: (() -> Bool)!
    var onDismiss: (() -> Void)!

    @Environment(\.colorScheme) var colorScheme: ColorScheme

    @State
    var showHex: Bool = false

    var body: some View {
        let mainBody = VStack(spacing: 20) {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "key")
                        .foregroundColor(.blue)
                        .font(.largeTitle)

                    Text("new_key_file_ready")
                        .font(.largeTitle)
                }

                Text("new_key_file_is_ready_desc")
            }

            VStack(alignment: .center, spacing: 8) {
                Text("new_key_file_next_steps")
                    .font(.title)

                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .center, spacing: 16) {
                        VStack(alignment: .leading) {
                            Text("new_key_file_step1_title")
                                .font(.headline)

                            Text("new_key_file_step1_message")

                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if showHex {
                            VStack(alignment: .leading, spacing: 20) {
                                VStack(alignment: .leading) {
                                    Text("key_file_hash_title")
                                        .font(.headline)

                                    Text(keyFile.hashString)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(colorScheme == .dark ? .yellow : Color.blue)
                                        .contextMenu(ContextMenu(menuItems: {
                                            Button("generic_action_verb_copy_to_clipboard", action: {
                                                #if os(macOS)
                                                    ClipboardManager.sharedInstance().copyNoneConcealedString(keyFile.hashString)
                                                #else
                                                    ClipboardManager.sharedInstance().copyStringWithNoExpiration(keyFile.hashString)
                                                #endif
                                            })
                                        }))
                                }

                                VStack(alignment: .leading) {
                                    Text("key_file_hex_codes")
                                        .font(.headline)

                                    Text(keyFile.formattedHex)
                                        .font(.system(.body, design: .monospaced))
                                        .fixedSize(horizontal: false, vertical: true)
                                        .foregroundColor(colorScheme == .dark ? .yellow : Color.blue)
                                        .contextMenu(ContextMenu(menuItems: {
                                            Button("generic_action_verb_copy_to_clipboard", action: {
                                                #if os(macOS)
                                                    ClipboardManager.sharedInstance().copyNoneConcealedString(keyFile.formattedHex)
                                                #else
                                                    ClipboardManager.sharedInstance().copyStringWithNoExpiration(keyFile.formattedHex)
                                                #endif
                                            })
                                        }))
                                }
                            }
                            .frame(minWidth: 0, maxWidth: .infinity)
                        }

                        let printButton = Button(action: {
                            onPrint()
                        }, label: {
                            HStack(spacing: 4) {
                                Image(systemName: "printer")

                                Text("new_key_file_print_recovery")
                            }
                        })

                        let showHexButton = Button(action: {
                            withAnimation {
                                showHex.toggle()
                            }
                        }, label: {
                            HStack(spacing: 4) {
                                Image(systemName: showHex ? "eye.slash" : "eye")

                                Text(showHex ? "new_key_file_hide_hex_codes" : "new_key_file_show_hex_codes")
                            }
                        })

                        #if os(macOS)
                            HStack(spacing: 20) {
                                printButton
                                    .controlSize(.large)
                                showHexButton
                                    .controlSize(.large)
                            }
                        #else
                            VStack(spacing: 30) {
                                showHexButton
                                printButton
                            }
                            .padding()
                        #endif
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading) {
                            Text("new_key_file_step2_save_key_file_title")
                                .font(.headline)

                            Text("new_key_file_step2_save_key_file_message")
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        let saveButton = Button(action: {
                            if onSave() {
                                onDismiss()
                            }
                        }, label: {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.down")

                                Text("new_key_file_save_key_file")
                            }
                        })
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .keyboardShortcut(.defaultAction)

                        #if os(macOS)
                            saveButton
                                .controlSize(.large)
                        #else
                            saveButton
                            Spacer()
                        #endif
                    }

                    #if os(iOS)
                        Button {
                            onDismiss()
                        } label: {
                            Text("generic_cancel")
                        }
                        .frame(minWidth: 0, maxWidth: .infinity)
                    #endif
                }
            }
        }

        #if os(macOS)
            return mainBody
                .frame(maxWidth: 450)
                .padding(30)
                .fixedSize()

        #else
            return mainBody
                .padding()
        #endif
    }
}

#Preview {
    GenerateKeyFileScreen(keyFile: KeyFile.newV2())
}
