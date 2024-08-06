//
//  HomeView.swift
//  Strongbox
//
//  Created by Strongbox on 28/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct HomeView: View {
    @ObservedObject
    var model: DatabaseHomeViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                if model.showFavouritesSection {
                    VStack(alignment: .leading, spacing: 8) {
                        DatabaseHomeViewHeader(title: "browse_vc_section_title_pinned", image: "star.fill", imageColor: .yellow)
                        FavoritesView(model: model)
                    }
                }

                if model.showNavigationSection {
                    VStack(alignment: .leading, spacing: 8) {
                        DatabaseHomeViewHeader(title: "generic_noun_navigation",
                                               subtitle: "home_view_navigation_section_subtitle",
                                               image: "location.fill", imageColor: .purple)
                        QuickNavigationView(model: model)
                    }
                }

                if model.showQuickTagsSection {
                    VStack(alignment: .leading, spacing: 8) {
                        DatabaseHomeViewHeader(title: "home_quick_tags_section_header",
                                               subtitle: "home_view_quick_tags_section_subtitle", image: "tag.fill", imageColor: .cyan)
                        TagsCloudView(model: model)
                    }
                }

                if model.showOtherViews {
                    VStack(alignment: .leading, spacing: 8) {
                        DatabaseHomeViewHeader(title: "quick_view_section_title_quick_views", subtitle: "home_view_other_views_navigation_section_subtitle", image: "scope", imageColor: .blue)
                        OtherViewsView(model: model)
                    }
                }
            }
            .padding()
        }
    }
}

@available(iOS 16.0, *)
#Preview {
    let model = DatabaseHomeViewModel(database: SwiftDummyDatabaseModel.testModel)

    @State
    var searchText = ""

    return NavigationStack {
        HomeView(model: model)
            .searchable(text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "generic_verb_search")
            .navigationTitle(model.database.nickName)
            .navigationBarTitleDisplayMode(.large)
    }
}
