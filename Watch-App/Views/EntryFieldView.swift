//
//  EntryFieldView.swift
//  Strongbox
//
//  Created by Strongbox on 14/12/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct EntryFieldView: View {
    var key: LocalizedStringKey?
    var value: String
    var concealed: Bool = false
    var markdown: Bool = false
    var pro: Bool
    var colorBlind: Bool

    var body: some View {
        NavigationLink {
            if concealed {
                ConcealedFieldDetailView(value: value, colorBlind: colorBlind)
            } else {
                LargeTextView(value: value, markdown: markdown, pro: pro)
            }
        } label: {
            VStack(alignment: .leading) {
                if let key {
                    Text(key)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if concealed {
                    Text("generic_masked_protected_field_text")
                        .lineLimit(1)
                } else {
                    let view = Text(value)
                        .lineLimit(1)

                    if pro {
                        view
                    } else {
                        HStack {
                            ProBadge()

                            view.blur(radius: 4)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        List {
            EntryFieldView(key: "generic_fieldname_username", value: "Testing33789912244", concealed: false, pro: true, colorBlind: false)
            EntryFieldView(key: "generic_fieldname_password", value: "Testing33789912244", concealed: true, pro: true, colorBlind: false)
        }
    }
}
