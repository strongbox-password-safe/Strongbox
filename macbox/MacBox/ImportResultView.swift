//
//  ImportResultView.swift
//  MacBox
//
//  Created by Strongbox on 04/07/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import SwiftUI

struct ImportResultView: View {
    var dismiss: ((_ cancel: Bool) -> Void)!
    var messages: [ImportMessage]

    var body: some View {
        #if os(macOS)
            macOSBody
        #else
            iOSBody
        #endif
    }

    #if os(iOS)
        var iOSBody: some View {
            NavigationView {
                VStack(spacing: 20) {
                    VStack(alignment: .center, spacing: 8) {
                        Text("import_successful_message")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if messages.count > 0 {
                        importMessagesList(messages: messages)
                    }

                    okCancelButtons
                    Spacer()
                }
                .padding(.horizontal, 20)
                .navigationTitle("import_successful_title")
                .navigationBarTitleDisplayMode(NavigationBarItem.TitleDisplayMode.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("generic_cancel") {
                            dismiss(true)
                        }
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
    #endif

    #if os(macOS)
        var macOSBody: some View {
            VStack(spacing: 20) {
                VStack(alignment: .center, spacing: 8) {
                    Text("import_successful_title")
                        .font(.largeTitle)

                    Text("import_successful_message")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if messages.count > 0 {
                    importMessagesList(messages: messages)
                }

                HStack {
                    Spacer()
                    okCancelButtons
                }
            }
            .frame(maxWidth: 450, maxHeight: 400)
            .padding(20)
        }
    #endif

    func importMessagesList(messages: [ImportMessage]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("import_messages_header")
                .font(.headline)

            let scroller = ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(messages) { message in
                        importMessageItem(message: message)

                        Divider()
                    }
                }
                .padding(8)
            }

            let support = Text("import_please_share_import_messages").font(.caption)

            VStack(alignment: .leading, spacing: 8) {
                #if os(macOS)
                    scroller
                        .border(.tertiary)
                        .frame(minHeight: 200)

                    support.textSelection(.enabled)
                #else
                    scroller
                        .border(.tertiary)
                        .frame(minHeight: 200)

                    support.textSelection(.enabled)
                #endif
            }
        }
    }

    var okCancelButtons: some View {
        HStack(spacing: 8) {
            let cancelButton = Button(action: {
                dismiss(true)
            }, label: {
                Text("generic_cancel")
            })

            #if os(macOS)
                let defaultButton = Button(action: {
                    dismiss(false)
                }, label: {
                    HStack {
                        Text("generic_lets_go").frame(minWidth: 100)


                    }
                })

                cancelButton
                    .controlSize(.large)
                    .keyboardShortcut(.cancelAction)

                defaultButton
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            #else
                let defaultButton = Button(action: {
                    dismiss(false)
                }, label: {
                    HStack {
                        Text("import_next_step_set_password")

                        Image(systemName: "chevron.forward.2")
                    }
                    .padding(12)
                })

                defaultButton
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .foregroundColor(Color.white)
                    .background(Color.blue)
                    .cornerRadius(5)
            #endif
        }
    }

    func importMessageItem(message: ImportMessage) -> some View {
        HStack(spacing: 8) {
            let severity = message.severity

            switch severity {
            case .info:
                Image(systemName: "info.circle")
                    .imageScale(.large)
                    .scaledToFit()
                    .foregroundColor(.blue)
            case .warning:
                Image(systemName: "exclamationmark.triangle")
                    .imageScale(.large)
                    .scaledToFit()
                    .foregroundColor(.orange)

            case .error:
                Image(systemName: "exclamationmark.circle")
                    .imageScale(.large)
                    .scaledToFit()
                    .foregroundColor(.red)
            }

            #if os(macOS)
                Text(message.message)
                    .font(.body)
                    .textSelection(.enabled)
            #else
                Text(message.message)
                    .font(.caption2)
            #endif
        }
    }
}

struct ImportResultView_Previews: PreviewProvider {
    static var previews: some View {
        let messages = [ImportMessage("Info message that's quite long", .info),
                        ImportMessage("A warning message that Also  message that's quite long", .warning),
                        ImportMessage("ERROR - ERRORERRORERROR ERROR- ERROR ERROR ERROR. A warning message that Also  message that's quite long. Info message that's quite long", .error),
                        ImportMessage("Info message that's quite long", .info),
                        ImportMessage("A warning message that Also  message that's quite long", .warning),
                        ImportMessage("ERROR - ERRORERRORERROR ERROR- ERROR ERROR ERROR. A warning message that Also  message that's quite long. Info message that's quite long", .error),
                        ImportMessage("Info message that's quite long", .info),
                        ImportMessage("A warning message that Also  message that's quite long", .warning),
                        ImportMessage("ERROR - ERRORERRORERROR ERROR- ERROR ERROR ERROR. A warning message that Also  message that's quite long. Info message that's quite long", .error)]

        ImportResultView(messages: messages)
    }
}
