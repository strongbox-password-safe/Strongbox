//
//  FavouriteCapsuleView.swift
//  Strongbox
//
//  Created by Strongbox on 27/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation
import SwiftUI

struct FavouriteCapsuleView: View {
    @Environment(\.colorScheme) var colorScheme

    @ObservedObject
    var model: DatabaseHomeViewModel

    var entry: any SwiftEntryModelInterface
    var easyReadSeparator: Bool

    var body: some View {
        Button(action: {
            model.actions.navigateTo(destination: .entryDetail(uuid: entry.uuid), homeModel: model)
        }, label: {
            HStack {
                if model.showIcons {
                    Image(uiImage: entry.image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .cornerRadius(3.0)
                        .shadow(radius: 3)
                        .foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(entry.title)
                            .font(.headline)

                        Spacer()

                        if let totp = entry.totp {
                            TotpView(totp: totp, easyReadSeparator: easyReadSeparator)
                        }
                    }

                    Text(entry.username)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .foregroundColor(.primary)
            .padding(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 0))
            .frame(width: 220, height: 50)
            .background(Color(white: colorScheme == .dark ? 0.1 : 0.9))
            .cornerRadius(8.0)
            .shadow(radius: 0.5)
        })
    }
}

#Preview {
    let foo = UIImage(systemName: "lock.fill")!

    let nodeIcon = NodeIcon.withPreset(0)



    let url = "otpauth:

    return VStack {
        FavouriteCapsuleView(model: DatabaseHomeViewModel(), entry: SwiftDummyEntryModel(title: "Test with a long title", imageSystemName: "lock.fill", totpUrl: url), easyReadSeparator: true)
        FavouriteCapsuleView(model: DatabaseHomeViewModel(), entry: SwiftDummyEntryModel(title: "Test1"), easyReadSeparator: true)
        FavouriteCapsuleView(model: DatabaseHomeViewModel(), entry: SwiftDummyEntryModel(title: "Test2"), easyReadSeparator: true)
        FavouriteCapsuleView(model: DatabaseHomeViewModel(), entry: SwiftDummyEntryModel(title: "Test3"), easyReadSeparator: true)
    }
}
