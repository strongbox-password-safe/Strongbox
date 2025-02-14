//
//  ToggleFavouriteButton.swift
//  Strongbox
//
//  Created by Strongbox on 29/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct ToggleAppleWatchButton: View {
    var model: DatabaseHomeViewModel
    var entry: any SwiftEntryModelInterface

    var body: some View {
        Button(action: {
            model.toggleAppleWatch(entry: entry)
        }) {
            let isWatchEntry = entry.isWatchEntry
            let title: LocalizedStringKey = isWatchEntry ? "action_remove_entry_from_apple_watch" : "action_add_entry_to_apple_watch"

            HStack {
                Text(title)
                Image(systemName: isWatchEntry ? "applewatch.slash" : "applewatch")
            }
        }
    }
}

struct ToggleFavouriteButton: View {
    var model: DatabaseHomeViewModel
    var entry: any SwiftEntryModelInterface

    var body: some View {
        Button(action: {
            model.toggleFavourite(entry: entry)
        }) {
            let pinned = entry.isFavourite
            let title: LocalizedStringKey = pinned ? "browse_vc_action_unpin" : "browse_vc_action_pin"

            HStack {
                Text(title)
                Image(systemName: pinned ? "star.slash" : "star")
                    .foregroundColor(.yellow)
            }
        }
    }
}

#Preview {
    ToggleFavouriteButton(model: DatabaseHomeViewModel(), entry: SwiftDummyEntryModel())
}
