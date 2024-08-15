//
//  PasskeyWizardAddExisting.swift
//  TestSwiftUINav
//
//  Created by Strongbox on 15/09/2023.

import SwiftUI

#if os(iOS)
    @available(iOS 17.0, *)
    struct PasskeyWizardAddExisting: View {
        @Environment(\.dismiss) private var dismiss

        @State private var searchText = ""
        @State private var showingConfirmation = false
        @State private var selectedEntry: Node? = nil

        let entries: [Node]
        var model: Model
        var completion: ((_ cancel: Bool, _ createNew: Bool, _ title: String?, _ selectedGroupIdx: Int?, _ selectedEntry: UUID?) -> Void)?

        

        var body: some View {
            List {
                Section {
                    ForEach(searchResults, id: \.self) { node in
                        Button(action: {
                            selectedEntry = node
                            showingConfirmation = true
                        }) {
                            let entry = SwiftEntryModel(node: node, model: model)
                            SwiftUIEntryView(entry: entry, showIcon: !model.metadata.hideIconInBrowse)
                        }
                    }
                } header: {
                    Text("quick_view_title_all_entries_title")
                }
            }
            .confirmationDialog(willOverwrite ? Text("passkey_overwrite_question_title") : Text(""), isPresented: $showingConfirmation, titleVisibility: willOverwrite ? .visible : .automatic) {
                Button(willOverwrite ? NSLocalizedString("passkey_option_overwrite", comment: "") : NSLocalizedString("alerts_yes", comment: ""), role: willOverwrite ? .destructive : nil) {
                    if let selectedEntry {
                        dismiss()
                        completion?(false, false, nil, nil, selectedEntry.uuid)
                    }
                }

                Button("alerts_no", role: .cancel, action: {})
            } message: {
                willOverwrite ?
                    Text(String(format: NSLocalizedString("passkey_overwrite_existing_question_msg_fmt", comment: "'%@' already has a passkey, are you sure you want to overwrite it?"), selectedEntryTitle)) :
                    Text(String(format: NSLocalizedString("passkeys_are_you_sure_add_to_fmt", comment: "Are you sure you want to add this passkey to '%@'?"), selectedEntryTitle))
            }
            .listStyle(.plain)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle(NSLocalizedString("passkey_select_existing_entry", comment: "Select entry for passkey"))
        }

        var selectedEntryTitle: String {
            selectedEntry?.title ?? "generic_unknown"
        }

        var willOverwrite: Bool {
            selectedEntry?.passkey != nil
        }

        var searchResults: [Node] {
            if searchText.isEmpty {
                return entries
            } else {
                return model.search(searchText, scope: .all, includeGroups: false)
            }
        }
    }
#else
    @available(macOS 14.0, *)
    struct PasskeyWizardAddExisting: View {
        @Environment(\.dismiss) private var dismiss

        enum FocusedField {
            case search
        }

        @FocusState private var focusedField: FocusedField?

        @State private var searchText = ""
        @State private var showingConfirmation = false
        @State private var selectedItem: Node? = nil

        let entries: [Node]
        var model: Model
        var completion: ((_ cancel: Bool, _ createNew: Bool, _ title: String?, _ selectedGroupIdx: Int?, _ selectedEntry: UUID?) -> Void)?

        var body: some View {
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("passkeys_select_existing_entry_to_add_to_title").font(.headline)
                    Text("passkeys_select_existing_entry_to_add_to_message").font(.subheadline)
                }

                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("generic_verb_search", text: $searchText)
                            .controlSize(.large)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .search)
                    }

                    List(selection: $selectedItem) {
                        ForEach(searchResults, id: \.self) { node in
                            let entry = SwiftEntryModel(node: node, model: model)
                            SwiftUIEntryView(entry: entry, showIcon: true)
                                .onDoubleClick {
                                    guard selectedItem != nil else { return }
                                    showingConfirmation = true
                                }
                        }
                    }
                    .cornerRadius(5.0)
                    .listStyle(.bordered)
                    .confirmationDialog(willOverwrite ? Text("passkey_overwrite_question_title") : Text("generic_are_you_sure"), isPresented: $showingConfirmation, titleVisibility: willOverwrite ? .visible : .automatic) {
                        Button(willOverwrite ? NSLocalizedString("passkey_option_overwrite", comment: "") : NSLocalizedString("alerts_yes", comment: ""), role: willOverwrite ? .destructive : nil) {
                            if let selectedItem {
                                dismiss()
                                completion?(false, false, nil, nil, selectedItem.uuid)
                            }
                        }

                        Button("alerts_no", role: .cancel, action: {})
                    } message: {
                        willOverwrite ?
                            Text(String(format: NSLocalizedString("passkey_overwrite_existing_question_msg_fmt", comment: "'%@' already has a passkey, are you sure you want to overwrite it?"), selectedEntryTitle)) :
                            Text(String(format: NSLocalizedString("passkeys_are_you_sure_add_to_fmt", comment: "Are you sure you want to add this passkey to '%@'?"), selectedEntryTitle))








                    }
                }

                HStack(spacing: 8) {
                    Button {
                        dismiss()
                        completion?(true, false, nil, nil, nil)
                    } label: {
                        Text("generic_cancel")
                    }
                    .controlSize(.large)
                    .keyboardShortcut(.cancelAction)

                    Button {
                        guard selectedItem != nil else { return }
                        showingConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.key.fill")
                                .foregroundColor(.white)

                            Text("passkey_save_passkey")
                                .font(.headline)
                        }
                        .padding(.horizontal)
                    }
                    .disabled(selectedItem == nil)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(minWidth: 400, minHeight: 500)
            .onAppear {
                focusedField = .search
                selectedItem = entries.first
            }
        }

        var selectedEntryTitle: String {
            selectedItem?.title ?? "generic_unknown"
        }

        var willOverwrite: Bool {
            guard let selectedItem else { return false }

            return selectedItem.passkey != nil
        }

        var searchResults: [Node] {
            if searchText.isEmpty {
                return entries
            } else {
                return model.searchAutoBestMatch(searchText, scope: .all)
            }
        }
    }
#endif
