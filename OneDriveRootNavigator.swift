//
//  OneDriveRootNavigator.swift
//  Strongbox
//
//  Created by Strongbox on 13/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct OneDriveRootNavigator: View {
    @State private var selection = Set<NavigationItem>()

    var selectExisting: Bool
    var appIsPro: Bool
    var completion: (_ cancelled: Bool, _ selectedMode: OneDriveNavigationContextMode) -> Void

    struct NavigationItem: Identifiable, Hashable {
        var id: OneDriveNavigationContextMode
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        let name: LocalizedStringKey
        let image: String
        let header: LocalizedStringKey
        let footer: LocalizedStringKey
        let pro: Bool

        init(id: OneDriveNavigationContextMode, name: LocalizedStringKey, image: String, header: LocalizedStringKey, footer: LocalizedStringKey, pro: Bool = false) {
            self.id = id
            self.name = name
            self.image = image
            self.header = header
            self.footer = footer
            self.pro = pro
        }
    }

    let allItems = [
        NavigationItem(id: .myDrives, name: "onedrive_browser_my_drives", image: "externaldrive.fill", header: "onedrive_browser_all_drives", footer: "onedrive_browser_your_onedrive_desc"),
        NavigationItem(id: .sharedWithMe, name: "onedrive_browser_shared_with_me", image: "externaldrive.fill.badge.person.crop", header: "onedrive_browser_shared", footer: "onedrive_browser_shared_desc"),
        NavigationItem(id: .sharepointSharedLibraries, name: "onedrive_browser_shared_libraries", image: "externaldrive.connected.to.line.below.fill", header: "onedrive_browser_sharepoint_sites", footer: "onedrive_browser_sharepoint_desc", pro: true),
    ]

    var filteredItems: [NavigationItem] {
        if !selectExisting {
            return allItems.filter { item in
                item.id != .sharedWithMe
            }
        } else {
            return allItems
        }
    }

    var body: some View {
        NavigationView {
            List(filteredItems, id: \.self, selection: $selection) { navItem in
                Section {
                    Button(action: {
                        completion(false, navItem.id)
                    }) {
                        HStack {
                            Image(systemName: navItem.image).foregroundColor(.blue)

                            NavigationLink(navItem.name, destination: EmptyView())
                        }
                    }
                    .foregroundColor(Color(uiColor: .label))
                } header: {
                    HStack {
                        Text(navItem.header).textCase(.uppercase)

                        if navItem.pro, !appIsPro {
                            ZStack {
                                Rectangle()
                                    .cornerRadius(5)
                                    .foregroundColor(.blue)
                                    .border(.clear)
                                    .frame(width: 45, height: 18)

                                Text("pro_badge_text")
                                    .bold()
                                    .foregroundColor(.white)
                            }
                        }
                    }
                } footer: {
                    Text(navItem.footer)
                }.textCase(nil)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("onedrive_explorer_title")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button(action: {
                completion(true, .initial)
            }) {
                Text("generic_cancel")
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

#Preview {
    OneDriveRootNavigator(selectExisting: true, appIsPro: false) { _, _ in
    }
}
