//
//  WatchListItemView.swift
//  Strongbox
//
//  Created by Strongbox on 13/12/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct WatchListItemView: View {
    var entry: WatchEntry
    var database: WatchDatabaseModel

    @EnvironmentObject
    var model: WatchAppModel

    var body: some View {
        HStack(spacing: 8) {
            let iconSet = KeePassIconSet(rawValue: database.iconSet)!

            if case .preset = entry.icon {
                if iconSet == .sfSymbols {
                    let icon = entry.icon.sfSymbolName

                    Image(systemName: icon)
                        .imageScale(.large)
                        .foregroundStyle(.blue)
                        .frame(width: 24)
                } else {
                    Image(uiImage: entry.icon.getUIImage(iconSet: iconSet))
                        .resizable()
                        .frame(width: 24, height: 24)
                        .cornerRadius(3)
                }
            } else {
                Image(uiImage: entry.icon.getUIImage(iconSet: iconSet))
                    .resizable()
                    .frame(width: 24, height: 24)
                    .cornerRadius(3)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(entry.title)
                    .font(.headline)
                    .lineLimit(1)

                let effectiveUser = entry.username.isEmpty ? entry.email : entry.username

                if !effectiveUser.isEmpty {
                    let userView = Text(effectiveUser)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if model.settings.pro {
                        userView
                    } else {
                        HStack {
                            ProBadge()

                            userView.blur(radius: 3)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    let entry = WatchEntry(title: "Testing Watch App with a Long Title",
                           icon: WatchEntryIcon.preset(icon: 1),
                           username: "username")

    let database = WatchDatabaseModel(nickName: "Database Name", uuid: "1234", iconSet: KeePassIconSet.sfSymbols.rawValue)

    return WatchListItemView(entry: entry, database: database)
        .environmentObject(WatchAppModel())
}