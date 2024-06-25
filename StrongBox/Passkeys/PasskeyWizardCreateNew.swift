//
//  PasskeyWizardCreateNew.swift
//  TestSwiftUINav
//
//  Created by Strongbox on 15/09/2023.
//

import SwiftUI

#if os(iOS)
    @available(iOS 17.0, *)
    struct PasskeyWizardCreateNew: View {
        @Environment(\.dismiss) private var dismiss

        @State var title: String
        @State var groups: [String]
        @State var selectedGroupIdx: Int

        var completion: ((_ cancel: Bool, _ createNew: Bool, _ title: String?, _ selectedGroupIdx: Int?, _ selectedEntry: UUID?) -> Void)?

        var body: some View {
            Form {
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.key.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)

                    VStack(spacing: 4) {
                        Text("passkey_new_entry_title")
                            .font(.title)

                        Text("passkey_new_entry_text")
                            .multilineTextAlignment(.center)
                            .font(.subheadline)
                    }
                }
                .padding()
                .listRowInsets(EdgeInsets())
                .listRowBackground(EmptyView())

                Section {
                    HStack {
                        Image(systemName: "person.badge.key.fill").foregroundColor(.secondary)
                        TextField("generic_fieldname_title", text: $title).foregroundColor(.primary)
                        Spacer()
                    }
                } header: {
                    Text("generic_fieldname_title")
                }

                Section {
                    Picker("", selection: $selectedGroupIdx) {
                        ForEach(groups.indices, id: \.self) { idx in
                            HStack {
                                Image(systemName: idx == 0 ? "house.fill" : "folder.fill")
                                Text(groups[idx]).foregroundColor(.primary)
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, -8)
                    .pickerStyle(.navigationLink)
                } header: {
                    Text("generic_field_name_group")
                }

                Section {
                    VStack(spacing: 16) {
                        Button {
                            dismiss()
                            completion?(false, true, title, selectedGroupIdx, nil)
                        } label: {
                            HStack {
                                Image(systemName: "person.badge.key.fill")
                                Text("passkey_save_passkey")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.blue)
                            .cornerRadius(5)
                        }
                        .buttonStyle(BorderlessButtonStyle()) 
                        
                        

                        Button {
                            dismiss()
                            completion?(true, true, nil, nil, nil)
                        } label: {
                            Text("generic_cancel")
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    .padding()
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(EmptyView())
            }
        }
    }

#else

    struct PasskeyWizardCreateNew: View {
        @Environment(\.dismiss) private var dismiss

        @State var title: String = "Relying Party"
        @State var groups: [String] = ["Database", "group2", "group3", "group4"]
        @State var selectedGroupIdx: Int = 0

        enum FocusedField {
            case title
        }

        @FocusState private var focusedField: FocusedField?

        var completion: ((_ cancel: Bool, _ createNew: Bool, _ title: String?, _ selectedGroupIdx: Int?, _ selectedEntry: UUID?) -> Void)?

        var body: some View {
            VStack(spacing: 20) {


                VStack(spacing: 4) {
                    Image("StrongBox-256x256")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundStyle(.tint)

                    VStack(spacing: 4) {
                        Text("passkey_new_entry_title")
                            .font(.title)

                        Text("passkey_new_entry_text")
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.center)
                            .font(.subheadline)
                    }
                }

                VStack(spacing: 16) {
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
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("generic_field_name_group").foregroundColor(.secondary)

                        Picker("", selection: $selectedGroupIdx) {
                            ForEach(groups.indices, id: \.self) { idx in
                                HStack {
                                    Image(systemName: idx == 0 ? "house.fill" : "folder.fill")
                                    Text(groups[idx]).foregroundColor(.primary)
                                }
                            }
                        }
                        .controlSize(.large)
                        .padding(.leading, -8)
                        .pickerStyle(.automatic)
                    }
                }

                HStack(spacing: 12) {
                    Button {


                        completion?(true, false, nil, nil, nil)
                    } label: {
                        Text("generic_cancel")
                    }
                    .controlSize(.large)
                    .keyboardShortcut(.cancelAction)

                    Button {


                        completion?(false, true, title, selectedGroupIdx, nil)
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.key.fill")
                            Text("passkey_save_passkey")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        .padding(.horizontal)
                    }
                    .controlSize(.large)
                    .cornerRadius(5)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(maxWidth: 400)
            .onAppear {
                focusedField = .title
            }
        }
    }
#endif
