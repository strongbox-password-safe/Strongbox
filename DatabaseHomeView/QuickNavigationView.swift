//
//  QuickNavigationView.swift
//  Strongbox
//
//  Created by Strongbox on 27/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation
import SwiftUI

struct QuickNavigationView: View {
    private let twoColumnGrid = [GridItem(.flexible()), GridItem(.flexible())]

    @ObservedObject
    var model: DatabaseHomeViewModel

    var body: some View {
        LazyVGrid(columns: twoColumnGrid) {
            if model.entryCount > 0 {
                NavigationCapsule(model: model, title: "quick_view_title_all_entries_title", image: "lock.fill", count: String(model.entryCount), imageBackgroundColor: .blue, destination: .allEntries)
            }

            if model.database.favourites.count > 0 {
                NavigationCapsule(model: model, title: "browse_vc_section_title_pinned", image: "star.fill", count: String(model.database.favourites.count), imageBackgroundColor: .orange, destination: .favourites)
            }

            if model.database.totpCodeEntries.count > 0 {
                NavigationCapsule(model: model, title: "quick_view_title_totp_entries_title", image: "timer", count: String(model.database.totpCodeEntries.count), imageBackgroundColor: .indigo, destination: .totps)
            }

            if model.database.groupCount > 0 {
                NavigationCapsule(model: model, title: "side_bar_hierarchy_folder_structure", image: "folder.fill", count: String(model.groupCount), imageBackgroundColor: .green, destination: .groups)
            }
        }
    }
}

#Preview {
    QuickNavigationView(model: DatabaseHomeViewModel())
}
