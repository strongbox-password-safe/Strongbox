//
//  PasscodeEntryView.swift
//  Strongbox
//
//  Created by Strongbox on 28/12/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Combine
import SwiftUI

struct SecureInputView: View {
    @Binding private var text: String
    @State private var isSecured: Bool = true
    private var title: LocalizedStringKey

    init(_ title: LocalizedStringKey, text: Binding<String>) {
        self.title = title
        _text = text
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Group {
                if isSecured {
                    SecureField(title, text: $text)
                } else {
                    TextField(title, text: $text)
                }
            }
            

            Button(action: {
                isSecured.toggle()
            }) {
                Image(systemName: isSecured ? "eye" : "eye.slash")
                    .accentColor(.blue)
                    .font(.system(size: 18))
            }
            .padding(8)
        }
    }
}

struct PasscodeEntryView: View {
    @Environment(\.presentationMode)
    var presentationMode

    var server: WiFiSyncServerConfig
    var onDone: (_ server: WiFiSyncServerConfig?, _ passcode: String?) -> Void

    @State
    var advancedPasscode = false

    @State
    var passcode = ""

    








    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "wifi")
                    .font(.system(size: 24))
                    .foregroundColor(.green)

                Text("storage_provider_name_wifi_sync")
                    .font(.title)
            }

            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "externaldrive.fill.badge.wifi")
                        .foregroundColor(.blue)

                    Text("\(server.name)").font(.headline)
                }

                Text("wifi_sync_enter_passcode_to_connect")
                    .font(.subheadline)
            }

            #if os(iOS)
                SecureInputView("wifi_sync_passcode_noun", text: $passcode)
                    .autocorrectionDisabled()
                    .autocapitalization(.none)
                    .keyboardType(advancedPasscode ? .default : .numberPad)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
                    .font(.largeTitle)

                    .padding(.horizontal, 30)
                    .focused()
                    .id(advancedPasscode)
            #else
                SecureInputView("wifi_sync_passcode_noun", text: $passcode)
            #endif

            Button {
                presentationMode.wrappedValue.dismiss()
                onDone(server, passcode)
            } label: {
                ZStack {
                    passcode.count > 0 ? Color.blue : Color.secondary

                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(passcode.count > 0 ? Color.primary : Color.secondary)

                        Text("generic_connect_verb")
                            .font(.headline)
                            .foregroundColor(passcode.count > 0 ? Color.primary : Color.secondary)
                    }
                }
                .frame(width: 250, height: 50)
            }
            .disabled(passcode.count == 0)
            .foregroundColor(.white)
            .cornerRadius(5)
            .keyboardShortcut(.defaultAction)

            Button("generic_cancel") {
                presentationMode.wrappedValue.dismiss()
                onDone(nil, nil)
            }

            VStack(alignment: .leading, spacing: 20) {
                Toggle(isOn: $advancedPasscode) {
                    Text("advanced_passcode_alphanumeric")
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "questionmark.circle")
                            .font(.caption)
                            .foregroundColor(.purple)

                        Text("generic_noun_tip_or_advice")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                    }

                    Text(String(format: NSLocalizedString("wifi_sync_tip_find_passcode_in_settings_fmt", comment: "You can find the Passcode to '%@' under Strongbox's Wi-Fi Sync Settings tab on your Mac."), server.name))
                        .font(.caption)
                }
            }

            Spacer()

        }.padding()
    }
}

#Preview {
    PasscodeEntryView(server: WiFiSyncServerConfig(name: "Marky Mark's Server"), onDone: { _, _ in

    })
}
