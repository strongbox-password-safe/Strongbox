//
//  DuplicateItemOptionsView.swift
//  MacBox
//
//  Created by Strongbox on 19/08/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct DuplicateItemOptionsView: View {
    enum FocusedField {
        case title
    }

    @FocusState private var focusedField: FocusedField?

    var showReferencingOptions: Bool
    @State var title: String
    @State var referencePassword: Bool
    @State var referenceUsername: Bool
    @State var preserveTimestamps: Bool
    @State var editAfterwards: Bool

    var completion: ((
        _ cancelled: Bool,
        _ title: String,
        _ referencePassword: Bool,
        _ referenceUsername: Bool,
        _ preserveTimestamps: Bool,
        _ editAfterwards: Bool
    ) -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "doc.on.doc")
                        .font(.title)
                        .foregroundColor(.blue)

                    Text("duplicate_item_title")
                        .font(.largeTitle)
                        .bold()
                }

                VStack(alignment: .leading, spacing: 20) {
                    TextField("generic_fieldname_title", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 350)
                        .focused($focusedField, equals: .title)

                    VStack(alignment: .leading) {
                        if showReferencingOptions {
                            Toggle("duplicate_item_option_reference_password", isOn: $referencePassword)
                            Toggle("duplicate_item_option_reference_username", isOn: $referenceUsername)
                        }
                        Toggle("duplicate_item_option_reference_timestamp", isOn: $preserveTimestamps)
                        Toggle("duplicate_item_option_reference_edit_afterwards", isOn: $editAfterwards)
                    }
                }
            }

            HStack(spacing: 8) {
                Button {
                    completion?(true, title, referencePassword, referenceUsername, preserveTimestamps, editAfterwards)
                } label: {
                    Text("generic_cancel")
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    completion?(false, title, referencePassword, referenceUsername, preserveTimestamps, editAfterwards)
                } label: {
                    HStack(spacing: 4) {
                        Text("browse_vc_action_duplicate")
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .controlSize(.large)
        .scenePadding()
        .onAppear {
            focusedField = .title
        }
    }
}

#Preview {
    DuplicateItemOptionsView(showReferencingOptions: true, title: "Item Copy", referencePassword: false, referenceUsername: false, preserveTimestamps: true, editAfterwards: false)
}
