//
//  AddOrCreateWizard.swift
//  TestSwiftUINav
//
//  Created by Strongbox on 15/09/2023.
//

import SwiftUI

struct AddOrCreateWizard: View {
    var mode: AddOrCreateWizardDisplayMode
    var title: String
    var groups: [String]
    var entries: [Node]
    var selectedGroupIdx: Int
    var model: Model
    var completion: ((_ cancel: Bool, _ createNew: Bool, _ title: String?, _ selectedGroupIdx: Int?, _ selectedEntry: UUID?) -> Void)?

    var body: some View {
        NavigationView {
            WizardChooseCreateOrAddView(mode: mode, title: title, groups: groups, entries: entries, model: model, completion: completion)
                .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .interactiveDismissDisabled() 
    }
}

#Preview {
    let database = DatabasePreferences.templateDummy(withNickName: "nick", storageProvider: .kLocalDevice, fileName: "filename.txt", fileIdentifier: "abx123")

    let model = Model(asDuressDummy: true, templateMetaData: database)

    let node1 = Node(parent: nil, title: "Foo Entry", isGroup: false, uuid: nil, fields: nil, childRecordsAllowed: false)

    return AddOrCreateWizard(mode: .totp, title: "", groups: ["Foo", "Bar"], entries: [node1], selectedGroupIdx: 0, model: model, completion: nil)
}
