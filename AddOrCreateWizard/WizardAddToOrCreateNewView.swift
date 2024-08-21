//
//  WizardAddToOrCreateNewView.swift
//  MacBox
//
//  Created by Strongbox on 18/08/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct WizardAddToOrCreateNewView: View {
    enum FocusedField {
        case search
    }

    @FocusState private var focusedField: FocusedField?

    var mode: AddOrCreateWizardDisplayMode

    @State private var searchText = ""
    @State private var showingConfirmation = false
    @State private var selectedItem: Node? = nil

    let entries: [Node]
    var model: Model

    @State var title: String
    @State var groups: [String]
    @State var showCreateNewSheet = false

    var completion: ((_ cancel: Bool, _ createNew: Bool, _ title: String?, _ selectedGroupIdx: Int?, _ selectedEntry: UUID?) -> Void)?

    var selectedEntryTitle: String {
        selectedItem?.title ?? "generic_unknown"
    }

    var willOverwrite: Bool {
        guard let selectedItem else { return false }

        switch mode {
        case .passkey:
            return selectedItem.passkey != nil
        case .totp:
            return selectedItem.fields.otpToken != nil
        }
    }

    var searchResults: [Node] {
        if searchText.isEmpty {
            return entries
        } else {
            return model.searchAutoBestMatch(searchText, scope: .all)
        }
    }

    var isSaveButtonEnabled: Bool {
        guard let selectedItem, searchResults.contains(selectedItem) else {
            return false
        }

        return true
    }

    var body: some View {
        VStack {
            VStack {
                HStack {
                    Image(systemName: mode.icon)
                        .font(.title)
                        .foregroundStyle(.tint)

                    Text(mode.itemName)
                        .bold()
                }
                .font(.largeTitle)

                Text(mode.addExistingTitle)
                    .font(.body)
            }

            VStack(spacing: 8) {
                HStack {
                    TextField("generic_verb_search", text: $searchText)
                        .controlSize(.large)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .search)
                        .frame(minWidth: 350, maxWidth: 400)
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
                .frame(maxWidth: 400, minHeight: 300)
                .cornerRadius(5.0)
                .listStyle(.bordered)
                .confirmationDialog(willOverwrite ? Text(mode.overwriteQuestion) : Text("generic_are_you_sure"),
                                    isPresented: $showingConfirmation, titleVisibility: willOverwrite ? .visible : .automatic)
                {
                    Button(willOverwrite ? NSLocalizedString("passkey_option_overwrite", comment: "Overwrite") : NSLocalizedString("alerts_yes", comment: "Yes"),
                           role: willOverwrite ? .destructive : nil)
                    {
                        if let selectedItem {
                            completion?(false, false, nil, nil, selectedItem.uuid)
                        }
                    }

                    Button("alerts_no", role: .cancel, action: {})
                } message: {
                    willOverwrite ?
                        Text(String(format: mode.overwriteQuestionMsgFmt, selectedEntryTitle)) :
                        Text(String(format: mode.questionMsgFmt, selectedEntryTitle))
                }
            }

            HStack(spacing: 8) {
                Button {
                    completion?(true, false, nil, nil, nil)
                } label: {
                    Text("generic_cancel")
                }
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    showCreateNewSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                        Text("generic_create_new_ellipsis")
                    }
                    .frame(width: 110)
                }
                .controlSize(.large)

                Button {
                    guard selectedItem != nil else { return }
                    showingConfirmation = true
                } label: {
                    HStack(spacing: 4) {
                        if isSaveButtonEnabled {
                            Text(String(format: NSLocalizedString("add_something_to_item_title_fmt", comment: "Add to '%@'"), selectedEntryTitle))
                        } else {
                            Text("casg_add_action")
                        }
                    }
                    .frame(width: 110)
                }
                .disabled(!isSaveButtonEnabled)
                .controlSize(.large)
            }
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showCreateNewSheet, content: {
            WizardCreateNewView(mode: mode, title: title, groups: groups, completion: completion)
        })
        .onAppear {
            focusedField = .search
            selectedItem = entries.first
        }
        .fixedSize()
        .scenePadding()
    }
}

#Preview {
    let database = MacDatabasePreferences.templateDummy(withNickName: "nick", storageProvider: .kLocalDevice, fileUrl: URL(string: "file:

    let dbModel = DatabaseModel()
    let model = Model(database: dbModel, metaData: database, forcedReadOnly: false, isAutoFill: false)!

    let node1 = Node(parent: nil, title: "Foo Entry that gets quite long", isGroup: false, uuid: nil, fields: nil, childRecordsAllowed: false)

    return WizardAddToOrCreateNewView(mode: .passkey,
                                      entries: [node1],
                                      model: model,
                                      title: "Test Title",
                                      groups: ["foo", "bar"])
}
