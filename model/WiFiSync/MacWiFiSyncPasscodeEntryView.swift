//
//  MacWiFiSyncPasscodeEntryView.swift
//  Strongbox
//
//  Created by Strongbox on 28/12/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

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
                        .font(.largeTitle)

                } else {
                    TextField(title, text: $text).font(.largeTitle)
                }
            }

            Button(action: {
                isSecured.toggle()
            }) {
                Image(systemName: isSecured ? "eye" : "eye.slash")
                    .accentColor(.blue)
                    .font(.system(size: 18))
            }
            .buttonStyle(.borderless)
            .controlSize(.large)
            .padding(8)
        }
    }
}

struct MacWiFiSyncPasscodeEntryView: View {
    var server: WiFiSyncServerConfig
    var onDone: (_ server: WiFiSyncServerConfig?, _ passcode: String?) -> Void

    @State
    var passcode = ""

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "wifi")
                        .font(.system(size: 24))
                        .foregroundColor(.green)

                    Text("storage_provider_name_wifi_sync")
                        .font(.title)
                }

                HStack {
                    Image(systemName: "externaldrive.fill.badge.wifi")
                        .foregroundColor(.blue)

                    Text("\(server.name)").font(.headline)
                }

                Text("wifi_sync_enter_passcode_to_connect")
                    .font(.subheadline)

                SecureInputView("wifi_sync_passcode_noun", text: $passcode)
                    .padding(.horizontal)

                VStack(alignment: .leading) {
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
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 20) {
                Button("generic_cancel") {
                    onDone(nil, nil)
                }
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)

                Button {
                    onDone(server, passcode)
                } label: {
                    HStack(spacing: 2) {

                        Text("generic_connect_verb")
                            .foregroundColor(passcode.count == 0 ? .secondary : .white)
                            .font(.headline)
                    }
                    .padding(.horizontal)
                }
                .disabled(passcode.count == 0)
                .controlSize(.large)
                .cornerRadius(5)
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(maxWidth: 350, maxHeight: 400)
        .padding(EdgeInsets(top: 20, leading: 8, bottom: 20, trailing: 8))
    }
}

#Preview {
    MacWiFiSyncPasscodeEntryView(server: WiFiSyncServerConfig(name: "Marky Mark's Wi-Fi Source"),
                                 onDone: { _, _ in

                                 })
}
