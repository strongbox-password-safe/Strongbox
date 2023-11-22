//
//  AutoFillCreateNewEntryDialog.swift
//  MacBox
//
//  Created by Strongbox on 12/10/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import SwiftUI

@available(macOS 13.0, *)
struct AutoFillCreateNewEntryDialog: View {



    @State var disableAllControlsBeforeDismiss = false

    @State var title: String = ""
    @State var url: String = ""
    @State var username: String = ""
    @State var password: String = ""
    @State var concealed: Bool = true
    @State var groups: [String] = ["Database", "group2", "group3", "group4"]
    @State var selectedGroupIdx: Int = 0

    func generateNewPassword() {
        password = PasswordMaker.sharedInstance().generate(forConfigOrDefault: Settings.sharedInstance().passwordGenerationConfig)
        concealed = false
    }

    enum FocusedField {
        case title
        case username
        case password
        case url
    }

    @FocusState private var focusedField: FocusedField?

    var completion: ((_ cancel: Bool, _ title: String, _ username: String, _ password: String, _ url: String, _ selectedGroupIdx: Int?) -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Image("StrongBox-256x256")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundStyle(.tint)

                VStack(spacing: 4) {
                    Text("autofill_create_new_entry_title")
                        .font(.title)

                    Text("autofill_create_new_entry_message")
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)
                        .font(.subheadline)
                }
            }

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("generic_field_name_group").foregroundColor(.secondary)

                    Picker("", selection: $selectedGroupIdx) {
                        ForEach(groups.indices, id: \.self) { idx in
                            HStack {
                                Image(systemName: idx == 0 ? "house.fill" : "folder.fill")
                                Text(groups[idx])
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .controlSize(.large)
                    .padding(.leading, -8)
                    .pickerStyle(.automatic)
                    .disabled(disableAllControlsBeforeDismiss)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.badge.key.fill")
                            .foregroundColor(.secondary)

                        Text("generic_fieldname_title")
                            .foregroundColor(.secondary)
                    }

                    TextField("generic_fieldname_title", text: $title)
                        .foregroundColor(.primary)
                        .controlSize(.large)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .title)
                        .disabled(disableAllControlsBeforeDismiss)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .foregroundColor(.secondary)

                        Text("generic_fieldname_username")
                            .foregroundColor(.secondary)
                    }

                    TextField("generic_fieldname_username", text: $username)
                        .foregroundColor(.primary)
                        .controlSize(.large)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .username)
                        .disabled(disableAllControlsBeforeDismiss)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "ellipsis.rectangle.fill")
                            .foregroundColor(.secondary)

                        Text("generic_fieldname_password")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        PasswordConcealRevealTextField(text: $password, isSecure: $concealed, titleKey: "generic_fieldname_password")
                            .focused($focusedField, equals: .password)
                            .disabled(disableAllControlsBeforeDismiss)

                        Button {
                            generateNewPassword()
                        } label: {
                            Image(systemName: "arrow.clockwise.circle.fill").imageScale(.large)
                        }
                        .buttonStyle(.borderless)
                        .disabled(disableAllControlsBeforeDismiss)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "link.circle")
                            .foregroundColor(.secondary)

                        Text("generic_fieldname_url")
                            .foregroundColor(.secondary)
                    }

                    TextField("generic_fieldname_url", text: $url)
                        .foregroundColor(.primary)
                        .controlSize(.large)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .url)
                        .disabled(disableAllControlsBeforeDismiss)
                }
            }

            HStack(spacing: 12) {
                Button {
                    disableAllControlsBeforeDismiss = true

                    completion?(true, title, username, password, url, nil)
                } label: {
                    Text("generic_cancel")
                }
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
                .disabled(disableAllControlsBeforeDismiss)

                Button {
                    disableAllControlsBeforeDismiss = true


                    completion?(false, title, username, password, url, selectedGroupIdx)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("mac_save_action")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                    .padding(.horizontal)
                }
                .controlSize(.large)
                .cornerRadius(5)
                .keyboardShortcut(.defaultAction)
                .disabled(disableAllControlsBeforeDismiss)
            }
        }
        .padding(20)
        .frame(maxWidth: 400)
        .onAppear {
            focusedField = .title
        }
    }
}
