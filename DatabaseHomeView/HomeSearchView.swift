//
//  HomeSearchView.swift
//  Strongbox
//
//  Created by Strongbox on 28/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct HomeSearchView: View {
    private struct SearchResultWrapperFFS: Identifiable {
        var id: UUID { result.uuid }
        var result: any SwiftEntryModelInterface
    }

    @ObservedObject
    var model: DatabaseHomeViewModel

    @Binding
    var searchText: String
    @Binding
    var searchScope: SearchScope

    private var searchResults: [SearchResultWrapperFFS] {
        let matches = model.search(searchText: searchText, searchScope: searchScope)

        return matches.map { SearchResultWrapperFFS(result: $0) }
    }

    @State
    var selection: Set<UUID> = .init()

    var body: some View {
        let list = List(searchResults, selection: $selection) { wrapper in
            Button(action: {
                model.navigateTo(destination: .entryDetail(uuid: wrapper.result.uuid))
            }, label: {
                SwiftUIEntryView(entry: wrapper.result, showIcon: model.showIcons)
                    .contextMenu {
                        EntryViewContextMenu(model: model, item: wrapper.result)
                    }
            })
        }

        if #available(iOS 17.0, *) {
            if searchResults.isEmpty, !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                list
            }
        } else {
            list
        }
    }
}

@available(iOS 16.0, *)
#Preview {
    let model = DatabaseHomeViewModel()

    @State
    var searchText: String = ""
    @State
    var searchScope: SearchScope = .all

    return NavigationStack {
        HomeSearchView(model: model, searchText: $searchText, searchScope: $searchScope)

            .searchable(text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "generic_verb_search")
            .navigationTitle(model.database.nickName)
            .navigationBarTitleDisplayMode(.large)
    }
}
