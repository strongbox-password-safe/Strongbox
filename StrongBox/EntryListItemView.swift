//
//  EntryListItemView.swift
//  Strongbox
//
//  Created by Strongbox on 17/09/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import SwiftUI

@available(iOS 15.0, macOS 14.0, *)
struct EntryListItemView: View {
    var title: String
    var username: String
    var path: String
    var icon: IMAGE_TYPE_PTR

    var body: some View {
        HStack {
            #if os(iOS)
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundColor(/*@START_MENU_TOKEN@*/ .blue/*@END_MENU_TOKEN@*/)
            #else
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundColor(/*@START_MENU_TOKEN@*/ .blue/*@END_MENU_TOKEN@*/)
            #endif
            VStack(alignment: .leading) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Spacer()
                }

                HStack {
                    Text(username)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Text(path)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }
}
