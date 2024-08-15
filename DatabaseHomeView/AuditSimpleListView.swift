//
//  AuditSimpleListView.swift
//  Strongbox
//
//  Created by Strongbox on 31/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct AuditSimpleListView: View {
    @ObservedObject
    var model: DatabaseHomeViewModel
    var title: LocalizedStringKey
    var list: [any SwiftEntryModelInterface]

    var body: some View {
        List {
            ForEach(list) { entry in
                Button {
                    model.navigateTo(destination: .entryDetail(uuid: entry.uuid))
                } label: {
                    NavigationLink(destination: EmptyView()) {
                        SwiftUIEntryView(entry: entry, showIcon: model.showIcons)
                            .contextMenu {
                                EntryViewContextMenu(model: model, item: entry)
                            }
                    }
                    .foregroundColor(Color(uiColor: .label))
                }
            }
        }
        .navigationTitle(title)
    }
}

#Preview {
    let list = [
        SwiftDummyEntryModel(title: "Alpha"),
        SwiftDummyEntryModel(title: "Alpha2"),
        SwiftDummyEntryModel(title: "Beta"),
    ]

    return NavigationView {
        AuditSimpleListView(model: DatabaseHomeViewModel(), title: "This is the title", list: list)
    }
}
