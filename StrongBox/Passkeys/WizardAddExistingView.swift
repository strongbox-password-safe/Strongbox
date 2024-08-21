//
//  WizardAddExistingView.swift
//  TestSwiftUINav
//
//  Created by Strongbox on 15/09/2023.

import SwiftUI

struct WizardAddExistingView: View {
    @State private var searchText = ""
    @State private var showingConfirmation = false
    @State private var selectedEntry: Node? = nil

    var mode: AddOrCreateWizardDisplayMode

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
        .confirmationDialog(willOverwrite ? Text(mode.overwriteQuestion) : Text(""), isPresented: $showingConfirmation, titleVisibility: willOverwrite ? .visible : .automatic) {
            Button(willOverwrite ? NSLocalizedString("passkey_option_overwrite", comment: "") : NSLocalizedString("alerts_yes", comment: ""), role: willOverwrite ? .destructive : nil) {
                if let selectedEntry {
                    completion?(false, false, nil, nil, selectedEntry.uuid)
                }
            }

            Button("alerts_no", role: .cancel, action: {})
        } message: {
            willOverwrite ?
                Text(String(format: mode.overwriteQuestionMsgFmt, selectedEntryTitle)) :
                Text(String(format: mode.questionMsgFmt, selectedEntryTitle))
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .navigationTitle(mode.addExistingTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    var selectedEntryTitle: String {
        selectedEntry?.title ?? "generic_unknown"
    }

    var willOverwrite: Bool {
        switch mode {
        case .passkey:
            selectedEntry?.passkey != nil
        case .totp:
            selectedEntry?.fields.otpToken != nil
        }
    }

    var searchResults: [Node] {
        if searchText.isEmpty {
            return entries
        } else {
            return model.search(searchText, scope: .all, includeGroups: false)
        }
    }
}

#Preview {
    let database = DatabasePreferences.templateDummy(withNickName: "nick", storageProvider: .kLocalDevice, fileName: "filename.txt", fileIdentifier: "abx123")

    let model = Model(asDuressDummy: true, templateMetaData: database)

    let node1 = Node(parent: nil, title: "Foo Entry", isGroup: false, uuid: nil, fields: nil, childRecordsAllowed: false)

    return NavigationView {
        WizardAddExistingView(mode: .totp, entries: [node1], model: model)
    }
}
