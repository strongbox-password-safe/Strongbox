//
//  PasskeyWizard.swift
//  TestSwiftUINav
//
//  Created by Strongbox on 15/09/2023.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct PasskeyWizard: View {
    var title: String
    var groups: [String]
    var entries: [Node]
    var selectedGroupIdx: Int
    var model: Model
    var completion: ((_ cancel: Bool, _ createNew: Bool, _ title: String?, _ selectedGroupIdx: Int?, _ selectedEntry: UUID?) -> Void)?

    var body: some View {
        NavigationStack {
            PasskeyWizardChooseCreateOrAdd(completion: completion)
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .navigationDestination(for: String.self) { des in
                    if des == "create" {
                        PasskeyWizardCreateNew(title: title, groups: groups, selectedGroupIdx: 0, completion: completion)
                    } else {
                        PasskeyWizardAddExisting(entries: entries, model: model, completion: completion)
                    }
                }
        }
        .interactiveDismissDisabled() 
    }
}
