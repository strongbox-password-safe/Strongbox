//
//  WatchEntryInnerListView.swift
//  Strongbox
//
//  Created by Strongbox on 14/12/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import OrderedCollections
import SwiftUI

struct WatchEntryInnerListView: View {
    var database: WatchDatabaseModel
    var entries: [WatchEntry]

    @EnvironmentObject
    var model: WatchAppModel

    var body: some View {
        ForEach(entries) { entry in
            NavigationLink {
                WatchEntryDetailView(entry: entry, database: database)
            } label: {
                ZStack(alignment: .leading) {
                    WatchListItemView(entry: entry, database: database)
                }
            }
        }
    }
}

#Preview {
    let database = WatchDatabaseModel(nickName: "Mark's Database", uuid: UUID().uuidString, iconSet: KeePassIconSet.sfSymbols.rawValue)

    let entry1 = WatchEntry(title: "Testing Watch App with a Long Title",
                            icon: WatchEntryIcon.preset(icon: 0),
                            username: "user")
    let entry2 = WatchEntry(title: "Entry 2",
                            icon: WatchEntryIcon.preset(icon: 1),
                            username: "username")
    let entry3 = WatchEntry(title: "My Bank",
                            icon: WatchEntryIcon.preset(icon: 2),
                            username: "mark")

    let entries = [entry1,
                   entry2,
                   entry3]

    NavigationView {
        List {
            WatchEntryInnerListView(database: database, entries: entries)
        }
    }
    .environmentObject(WatchAppModel())
}
