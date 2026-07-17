//
//  DatabaseHomeView.swift
//  Strongbox
//
//  Created by Strongbox on 26/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct DatabaseHomeView: View {
    @ObservedObject
    var model: DatabaseHomeViewModel

    @State var isFirstAppearance = true
    @State var searchText = ""
    @State var searchScope: SearchScope = AppPreferences.sharedInstance().initialSearchScope
    @State var isSearchPresented = false

    let scopes: [SearchScope] = [.title, .username, .password, .url, .tags, .all]

    func getScopeDisplayName(scope: SearchScope) -> String {
        switch scope {
        case .title:
            NSLocalizedString("browse_vc_search_scope_title", comment: "Title")
        case .username:
            NSLocalizedString("browse_vc_search_scope_username", comment: "Username")
        case .password:
            NSLocalizedString("browse_vc_search_scope_password", comment: "Password")
        case .url:
            NSLocalizedString("browse_vc_search_scope_url", comment: "URL")
        case .tags:
            NSLocalizedString("browse_vc_search_scope_tags", comment: "Tags")
        case .all:
            NSLocalizedString("browse_vc_search_scope_all", comment: "All")
        @unknown default:
            NSLocalizedString("generic_unknown", comment: "Unknown")
        }
    }

    init(model: DatabaseHomeViewModel, searchText: String = "", isSearchPresented: Bool = false) {
        self.model = model
        self.searchText = searchText
        self.isSearchPresented = isSearchPresented
    }

    var body: some View {
        let view = Group {
            if #available(iOS 17.0, *) {
                if isSearchPresented {
                    HomeSearchView(model: model, searchText: $searchText, searchScope: $searchScope)
                } else {
                    if model.allHomeSectionsInvisible {
                        Text("home_view_all_sections_hidden")
                            .font(.headline)
                        Text("home_view_all_sections_hidden_instructions")
                            .font(.subheadline)
                    } else if model.showEmptyDatabaseView {
                        ContentUnavailableView {
                            Label("pick_creds_vc_empty_dataset_title", systemImage: "lock.rectangle").foregroundColor(.secondary)
                        }
                    } else {
                        HomeView(model: model)
                    }
                }
            } else {
                if !searchText.isEmpty {
                    HomeSearchView(model: model, searchText: $searchText, searchScope: $searchScope)
                } else if model.allHomeSectionsInvisible {
                    Text("home_view_all_sections_hidden")
                        .font(.headline)
                    Text("home_view_all_sections_hidden_instructions")
                        .font(.subheadline)
                } else {
                    HomeView(model: model)
                }
            }
        }
        .refreshable {
            await model.onPulldownToRefresh()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                HStack {
                    Button(action: {
                        model.close()
                    }) {
                        Text("generic_verb_close")
                    }

                    SettingsNavBarButton(model: model)
                }
            }

            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(model.title)
                        .lineLimit(1)
                        .font(.headline)

                    if !model.subtitle.isEmpty {
                        Text(model.subtitle)
                            .font(.caption2)
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    SyncNavBarButton(model: model)
                    MoreNavBarButton(model: model)
                }
            }
        }
        .onAppear(perform: {
            swlog("🐞 DatabaseHomeView onAppear")

            if isFirstAppearance {
                isFirstAppearance = false
                isSearchPresented = model.startWithSearch && !model.hasDoneDatabaseOnLaunchTasks
                model.hasDoneDatabaseOnLaunchTasks = true
            } else {
                model.objectWillChange.send() 
            }
        })
        .onReceive(NotificationCenter.default.publisher(for: .modelEdited, object: nil)) { _ in
            swlog("🐞 DatabaseHomeView received modelEdited")
            model.objectWillChange.send() 
        }
        .onReceive(NotificationCenter.default.publisher(for: .databaseUpdated, object: nil)) { _ in
            swlog("🐞 DatabaseHomeView received databaseUpdated")
            model.objectWillChange.send() 
        }
        .onReceive(NotificationCenter.default.publisher(for: .auditCompleted, object: nil)) { _ in
            swlog("🐞 DatabaseHomeView received auditCompleted")
            model.objectWillChange.send() 
        }
        .onReceive(NotificationCenter.default.publisher(for: .databaseReloaded, object: nil)) { _ in
            swlog("🐞 DatabaseHomeView received databaseReloaded")
            model.objectWillChange.send() 
        }

        if #available(iOS 17.0, *) {
            return view
                .searchable(text: $searchText,
                            isPresented: $isSearchPresented,
                            placement: .navigationBarDrawer(displayMode: .always),
                            prompt: "generic_verb_search")
                .searchScopes($searchScope) {
                    ForEach(scopes, id: \.self) { scope in
                        Text(getScopeDisplayName(scope: scope))
                    }
                }
                .onChange(of: searchScope) { newScope in
                    AppPreferences.sharedInstance().persistSearchScope(ifEnabled: newScope)
                }
                .onChange(of: isSearchPresented) { presented in
                    if presented { 
                        searchScope = AppPreferences.sharedInstance().initialSearchScope
                    }
                }

        } else {
            return view
                .searchable(text: $searchText,
                            placement: .navigationBarDrawer(displayMode: .always),
                            prompt: "generic_verb_search")
        }
    }
}

#Preview {
    let model = DatabaseHomeViewModel(database: SwiftDummyDatabaseModel.testModel)

    return NavigationView {
        DatabaseHomeView(model: model)
    }
}
