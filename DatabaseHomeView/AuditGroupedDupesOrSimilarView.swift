//
//  AuditGroupedDupesOrSimilarView.swift
//  Strongbox
//
//  Created by Strongbox on 31/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct AuditGroupedDupesOrSimilarView: View {
    @ObservedObject
    var model: DatabaseHomeViewModel

    enum GroupedViewMode {
        case duplicates
        case similar
    }

    var viewMode = GroupedViewMode.duplicates
    var grouped: [String: [any SwiftEntryModelInterface]]

    init(model: DatabaseHomeViewModel, viewMode: GroupedViewMode = GroupedViewMode.duplicates) {
        self.model = model
        self.viewMode = viewMode
        grouped = viewMode == .duplicates ? model.auditModel.duplicated : model.auditModel.similar
    }

    var sortedKeys: [String] {
        grouped.keys.sorted { key1, key2 in
            let group1 = grouped[key1] ?? []
            let group2 = grouped[key2] ?? []

            if group1.count == group2.count {
                return key1 < key2
            }

            return group1.count > group2.count
        }
    }

    var body: some View {
        List {
            ForEach(Array(sortedKeys.enumerated()), id: \.offset) { index, key in
                Section(sortedKeys.count > 1 ? String(format: NSLocalizedString("anonymous_group_number_fmt", comment: "Group %@"), String(index + 1)) : "") {
                    if let entries = grouped[key] {
                        ForEach(entries) { entry in
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
                }
            }
        }
        .navigationTitle(viewMode == .duplicates ? "audit_quick_summary_very_brief_duplicated_password" : "audit_quick_summary_very_brief_password_is_similar_to_another")
    }
}

#Preview {
    var db = SwiftDummyDatabaseModel()

    let duplicated = [
        "a2": [
            SwiftDummyEntryModel(title: "Alpha"),
            SwiftDummyEntryModel(title: "Alpha2"),
            SwiftDummyEntryModel(title: "Beta")],
        "a1": [
            SwiftDummyEntryModel(title: "Gamma"),
            SwiftDummyEntryModel(title: "Gamma2"),
            SwiftDummyEntryModel(title: "Delta")],
    ]

    let similar = duplicated

    db.auditModel = AuditViewModel(duplicated: duplicated, similar: similar)

    return NavigationView {
        AuditGroupedDupesOrSimilarView(model: DatabaseHomeViewModel(database: db), viewMode: .similar)
    }
}
