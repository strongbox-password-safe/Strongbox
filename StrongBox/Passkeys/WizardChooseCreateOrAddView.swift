//
//  WizardChooseCreateOrAddView.swift
//  TestSwiftUINav
//
//  Created by Strongbox on 15/09/2023.
//

import SwiftUI

private struct ButtonsView: View {
    var mode: AddOrCreateWizardDisplayMode

    var title: String
    var groups: [String]
    var entries: [Node]
    var model: Model

    var completion: ((_ cancel: Bool, _ createNew: Bool, _ title: String?, _ selectedGroupIdx: Int?, _ selectedEntry: UUID?) -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            NavigationLink(destination: {
                WizardCreateNewView(mode: mode, title: title, groups: groups, selectedGroupIdx: 0, completion: completion)
            }, label: {
                Text("passkey_add_by_creating_new")
                    .frame(maxWidth: .infinity)
                    .font(.headline)
            })

            NavigationLink(destination: {
                WizardAddExistingView(mode: mode, entries: entries, model: model, completion: completion)
            }, label: {
                Text("passkey_add_to_existing")
                    .frame(maxWidth: .infinity)
                    .font(.headline)
            })
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .fixedSize()
    }
}

struct WizardChooseCreateOrAddView: View {
    @Environment(\.dismiss) private var dismiss

    var mode: AddOrCreateWizardDisplayMode

    var title: String
    var groups: [String]
    var entries: [Node]
    var model: Model

    var completion: ((_ cancel: Bool, _ createNew: Bool, _ title: String?, _ selectedGroupIdx: Int?, _ selectedEntry: UUID?) -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            VStack {
                HStack {
                    Image(systemName: mode.icon)
                        .font(.largeTitle)
                        .foregroundColor(.blue)

                    Text(mode.title)
                        .font(.largeTitle)
                        .bold()
                }

                Text(mode.subtitle)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 350)
                    .font(.subheadline)
            }

            ButtonsView(mode: mode, title: title, groups: groups, entries: entries, model: model, completion: completion)

            Button {
                dismiss()
                completion?(true, false, nil, nil, nil)
            } label: {
                Text("generic_cancel")
            }
            .keyboardShortcut(.cancelAction)
        }
        .scenePadding()
    }
}

#Preview {
    let database = DatabasePreferences.templateDummy(withNickName: "nick", storageProvider: .kLocalDevice, fileName: "filename.txt", fileIdentifier: "abx123")

    let model = Model(asDuressDummy: true, templateMetaData: database)

    let node1 = Node(parent: nil, title: "Foo Entry", isGroup: false, uuid: nil, fields: nil, childRecordsAllowed: false)

    return WizardChooseCreateOrAddView(mode: .passkey, title: "Title", groups: ["Foo", "Bar"], entries: [node1], model: model)
}
