//
//  OtherViewsView.swift
//  Strongbox
//
//  Created by Strongbox on 27/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation
import SwiftUI

struct OtherViewsView: View {
    private let twoColumnGrid = [GridItem(.flexible()), GridItem(.flexible())]

    @ObservedObject
    var model: DatabaseHomeViewModel

    var body: some View {
        LazyVGrid(columns: twoColumnGrid) {
            if model.database.tagCount > 0 {
                NavigationCapsule(model: model, title: "quick_view_title_all_tags_title", image: "tag.fill", count: String(model.database.tagCount), imageBackgroundColor: .blue, destination: .tags(tag: nil))
            }

            let auditModel = model.database.auditModel
            if auditModel.isEnabled {
                let issueCount = model.database.auditIssueEntryCount
                NavigationCapsule(model: model,
                                  title: "browse_vc_action_audit",
                                  image: "checkmark.shield.fill",
                                  count: issueCount == 0 ? "" : String(issueCount),
                                  imageBackgroundColor: issueCount == 0 ? .green : .orange,
                                  destination: .auditIssues)
            }

            if model.database.passkeyEntryCount > 0 {
                NavigationCapsule(model: model, title: "generic_noun_plural_passkeys", image: "person.badge.key.fill", count: String(model.database.passkeyEntryCount), imageBackgroundColor: .purple, destination: .passkeys)
            }

            if model.database.sshKeyEntryCount > 0 {
                if #available(iOS 17.0, *) {
                    NavigationCapsule(model: model, title: "sidebar_quick_view_keeagent_ssh_keys_title", image: "apple.terminal.fill", count: String(model.database.sshKeyEntryCount), imageBackgroundColor: .indigo, destination: .sshKeys)
                } else {
                    NavigationCapsule(model: model, title: "sidebar_quick_view_keeagent_ssh_keys_title", image: "network", count: String(model.database.sshKeyEntryCount), imageBackgroundColor: .indigo, destination: .sshKeys)
                }
            }

            if model.database.attachmentsEntryCount > 0 {
                NavigationCapsule(model: model, title: "item_details_section_header_attachments", image: "doc.richtext.fill", count: String(model.database.attachmentsEntryCount), imageBackgroundColor: .mint, destination: .attachments)
            }

            if model.expireCount > 0 {
                NavigationCapsule(model: model, title: "quick_view_title_expired_and_expiring", image: "calendar", count: String(model.expireCount), imageBackgroundColor: .cyan, destination: .expiredAndExpiring)
            }

            if let recycleBinGroup = model.recycleBinGroup, model.database.recycleBinCount > 0 {
                NavigationCapsule(model: model, title: "generic_recycle_bin_name", image: "trash.fill", count: String(model.database.recycleBinCount), imageBackgroundColor: .yellow, destination: .recycleBin)
                    .contextMenu {
                        EntryViewContextMenu(model: model, item: recycleBinGroup)
                    }
            }
        }
    }
}

#Preview {
    OtherViewsView(model: DatabaseHomeViewModel(database: SwiftDummyDatabaseModel.testModel))
}
