//
//  FavoritesView.swift
//  Strongbox
//
//  Created by Strongbox on 27/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation
import SwiftUI












struct FavoritesView: View {
    private var rows: [GridItem] {
        var full = [
            GridItem(.flexible(minimum: 50)),
            GridItem(.flexible(minimum: 0)),
            GridItem(.flexible(minimum: 0)),
        ]

        let count = model.database.favourites.count

        
        
        

        if count < 5 {
            full.removeLast()
        }
        if count < 3 {
            full.removeLast()
        }

        return full
    }

    @ObservedObject
    var model: DatabaseHomeViewModel

    var body: some View {
        ScrollView(.horizontal) {
            LazyHGrid(rows: rows, alignment: .top) {
                ForEach(model.database.favourites) { favourite in
                    FavouriteCapsuleView(model: model, entry: favourite)
                        .contextMenu {
                            EntryViewContextMenu(model: model, item: favourite)
                        }
                }
            }
        }
    }
}

#Preview {
    let favs = [SwiftDummyEntryModel(title: "HSBC UK 1", imageSystemName: "doc", favourite: true),
                SwiftDummyEntryModel(title: "Strava 2", imageSystemName: "doc", favourite: true),






    ]

    let database = SwiftDummyDatabaseModel()
    database.entries = favs

    let model = DatabaseHomeViewModel(database: database)
    return
        List {
            FavoritesView(model: model)
        }
}
