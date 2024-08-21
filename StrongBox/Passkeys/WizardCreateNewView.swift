//
//  WizardCreateNewView.swift
//  TestSwiftUINav
//
//  Created by Strongbox on 15/09/2023.
//

import SwiftUI

private struct HeadingView: View {
    var mode: AddOrCreateWizardDisplayMode

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: mode.icon)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.tint)

            VStack(spacing: 2) {
                Text(mode.title)
                    .font(.largeTitle)
                    .bold()

                Text(mode.createSubtitle)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 350)
                    .font(.subheadline)
            }
        }
    }
}

#if os(iOS)
    struct WizardCreateNewView: View {
        enum FocusedField {
            case title
        }

        @FocusState private var focusedField: FocusedField?

        var mode: AddOrCreateWizardDisplayMode

        @State var title: String
        @State var groups: [String]
        @State var selectedGroupIdx: Int

        var completion: ((_ cancel: Bool, _ createNew: Bool, _ title: String?, _ selectedGroupIdx: Int?, _ selectedEntry: UUID?) -> Void)?

        var body: some View {
            Form {
                HeadingView(mode: mode)
                    .padding()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(EmptyView())

                Section {
                    HStack {
                        Image(systemName: mode.icon)
                            .foregroundColor(.secondary)

                        TextField("generic_fieldname_title", text: $title)
                            .focused($focusedField, equals: .title)
                    }
                } header: {
                    Text("generic_fieldname_title")
                }

                Section {
                    let picker = Picker("", selection: $selectedGroupIdx) {
                        ForEach(groups.indices, id: \.self) { idx in
                            HStack {
                                Image(systemName: idx == 0 ? "house.fill" : "folder.fill")
                                Text(groups[idx]).foregroundColor(.primary)
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, -8)

                    if #available(iOS 16.0, *) {
                        picker.pickerStyle(.navigationLink)
                    } else {
                        picker
                    }
                } header: {
                    Text("generic_field_name_group")
                }
            }
            .onAppear {
                focusedField = .title
            }
            .toolbar(content: {
                ToolbarItem(placement: .confirmationAction) {
                    HStack {
                        Button(action: {
                            completion?(false, true, title, selectedGroupIdx, nil)
                        }) {
                            Text("mac_save_action")
                        }
                    }
                }
            })
        }
    }

#else

    struct WizardCreateNewView: View {
        @Environment(\.dismiss) private var dismiss

        var mode: AddOrCreateWizardDisplayMode

        @State var title: String
        @State var groups: [String]
        @State var selectedGroupIdx: Int = 0

        enum FocusedField {
            case title
        }

        @FocusState private var focusedField: FocusedField?

        var completion: ((_ cancel: Bool, _ createNew: Bool, _ title: String?, _ selectedGroupIdx: Int?, _ selectedEntry: UUID?) -> Void)?

        var body: some View {
            VStack(spacing: 20) {
                HeadingView(mode: mode)

                VStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: mode.icon)
                                .foregroundColor(.secondary)

                            Text("generic_fieldname_title")
                                .foregroundColor(.secondary)
                        }

                        TextField("generic_fieldname_title", text: $title)
                            .foregroundColor(.primary)
                            .controlSize(.large)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .title)
                            .frame(maxWidth: 350)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("generic_field_name_group").foregroundColor(.secondary)

                        Picker("", selection: $selectedGroupIdx) {
                            ForEach(groups.indices, id: \.self) { idx in
                                HStack {
                                    Image(systemName: idx == 0 ? "house.fill" : "folder.fill")
                                    Text(groups[idx])

                                }
                            }
                        }
                        .frame(maxWidth: 350)
                        .controlSize(.large)
                        .padding(.leading, -8)

                    }
                }

                HStack(spacing: 8) {
                    Button {
                        swlog("🟢 CANCEL")
                        
                        dismiss()
                        completion?(true, false, nil, nil, nil)
                    } label: {
                        Text("generic_cancel")
                    }
                    .controlSize(.large)
                    .keyboardShortcut(.cancelAction)

                    Button {
                        dismiss()
                        swlog("🟢 NOT CANCEL")
                        
                        completion?(false, true, title, selectedGroupIdx, nil)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: mode.icon)
                            Text("mac_save_action")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        .padding(.horizontal)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.bottom)
            }
            .fixedSize()
            .scenePadding()
            .onAppear {
                focusedField = .title
            }
        }
    }
#endif

#Preview {
    #if os(iOS)
        NavigationView {
            WizardCreateNewView(mode: .totp,
                                title: "Test Title",
                                groups: ["foo", "bar"],
                                selectedGroupIdx: 0)
        }
    #else
        WizardCreateNewView(mode: .passkey,
                            title: "Test Title",
                            groups: ["foo", "bar"],
                            selectedGroupIdx: 0)
    #endif
}
