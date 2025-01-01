//
//  WatchHomeScreen.swift
//  Strongbox
//
//  Created by Strongbox on 19/12/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import OrderedCollections
import SwiftUI

struct WatchHomeScreen: View {
    @EnvironmentObject
    var model: WatchAppModel

    var body: some View {
        NavigationView {
            Group {
                if model.entryList.keys.elements.isEmpty {
                    WatchEmptyView()
                } else {
                    WatchEntryListView()
                }
            }
            .navigationTitle("Strongbox")
        }
    }
}

#Preview {
    WatchHomeScreen()
        .environmentObject(WatchAppModel())
}
