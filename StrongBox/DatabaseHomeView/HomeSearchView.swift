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

    @AppStorage(
        "search_allow_expired",
        store: AppPreferences.sharedInstance().sharedAppGroupDefaults
    ) var allowExpired: Bool = false

    @ObservedObject
    var model: DatabaseHomeViewModel

    @Binding
    var searchText: String
    @Binding
    var searchScope: SearchScope

    private var searchResults: [SearchResultWrapperFFS] {
        let matches = model.search(searchText: searchText, searchScope: searchScope, allowExpired: allowExpired)

        return matches.map { SearchResultWrapperFFS(result: $0) }
    }

    @State
    var selection: Set<UUID> = .init()

    var body: some View {
        Group {
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
        .overlay(alignment: .bottom) {
            HStack {
                Spacer()

                Toggle(isOn: $allowExpired, label: {
                    Text("search_show_expired")
                })
                .font(.subheadline.weight(.regular))
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Material.bar)
            .overlay(alignment: .top) {
                Divider()
            }
        }
        .animation(.snappy, value: searchResults.count)
    }

    var list: some View {
        List(searchResults, selection: $selection) { wrapper in
            Button(action: {
                model.navigateTo(destination: .entryDetail(uuid: wrapper.result.uuid))
            }, label: {
                SwiftUIEntryView(entry: wrapper.result, showIcon: model.showIcons, easyReadSeparator: model.twoFactorShowSeparator)
                    .contextMenu {
                        EntryViewContextMenu(model: model, item: wrapper.result)
                    }.id(UUID()) 
            })
        }
        .transition(.opacity.animation(.snappy))
    }
}

@available(iOS 17.0, *)
#Preview {
    @Previewable @State
    var searchText: String = ""
    @Previewable @State
    var searchScope: SearchScope = .all

    let model = DatabaseHomeViewModel()

    return NavigationStack {
        HomeSearchView(model: model, searchText: $searchText, searchScope: $searchScope)

            .searchable(text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "generic_verb_search")
            .navigationTitle(model.database.nickName)
            .navigationBarTitleDisplayMode(.large)
    }
}
