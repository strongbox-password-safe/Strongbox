//
//  WatchEntryListView.swift
//  strongbox.watch.pro Watch App
//
//  Created by Strongbox on 07/12/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import OrderedCollections
import SwiftUI

struct WatchEntryListView: View {
    @EnvironmentObject
    var model: WatchAppModel

    var body: some View {
        List {
            ForEach(model.entryList.keys.elements) { database in
                if let entries = model.entryList[database] {
                    if model.entryList.keys.count > 1 {
                        Section(header: Text(database.nickName).foregroundStyle(.secondary)) {
                            WatchEntryInnerListView(database: database, entries: entries)
                        }
                    } else {
                        WatchEntryInnerListView(database: database, entries: entries)
                    }
                }
            }













        }
    }
}
