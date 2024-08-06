//
//  TagsNGTableViewCell.swift
//  Strongbox
//
//  Created by Strongbox on 26/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI
import UIKit

@available(iOS 16.0, *)
@objc
class TagsNGTableViewCell: UITableViewCell {
    @objc
    static let CellIdentifier = "TagsNGTableViewCell"

    @objc
    func setContent(tags: [String], useEasyReadFont: Bool, isEditing: Bool) {
        if tags.isEmpty {
            if isEditing {
                setEditingPromptToAddContent()
            } else {
                setEmptyContent()
            }
        } else {
            setSomeTagsContent(tags: tags, useEasyReadFont: useEasyReadFont)
        }

        clipsToBounds = true
    }

    private func setSomeTagsContent(tags: [String], useEasyReadFont: Bool) {
        let vm = TagsViewModel(tags: tags)

        let content = {
            TagsView(viewModel: vm, useEasyReadFont: useEasyReadFont)
        }

        contentConfiguration = UIHostingConfiguration(content: content)
    }

    private func setEmptyContent() {
        contentConfiguration = UIHostingConfiguration {
            EmptyView()
        }
    }

    private func setEditingPromptToAddContent() {
        let content = {
            HStack {
                Group {
                    Image(.customTagFillBadgePlus)
                        .foregroundStyle(.green, .blue)

                    Text("item_details_tap_to_add_tags")
                }
                .padding(.vertical, 4)
            }
        }

        contentConfiguration = UIHostingConfiguration(content: content)
    }
}
