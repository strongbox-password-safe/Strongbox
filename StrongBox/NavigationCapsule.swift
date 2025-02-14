//
//  NavigationCapsule.swift
//  Strongbox
//
//  Created by Strongbox on 26/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation
import SwiftUI

struct NavigationCapsule: View {
    @Environment(\.colorScheme) var colorScheme

    @ObservedObject
    var model: DatabaseHomeViewModel

    var title: LocalizedStringKey
    var image: String
    var count: String
    var imageBackgroundColor: Color
    var destination: DatabaseNavigationDestination

    var body: some View {
        Button(action: {
            model.navigateTo(destination: destination)
        }, label: {
            ZStack(alignment: .topTrailing) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: image)
                            .padding(8)
                            .foregroundColor(.white)
                            .background(imageBackgroundColor)
                            .clipShape(.circle)
                            .frame(height: 32)

                        Text(title)
                            .font(.subheadline)
                            .lineLimit(1)
                    }

                    Spacer()
                }

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(count)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(Color(white: colorScheme == .dark ? 0.1 : 0.9))
            .cornerRadius(8.0)
            .shadow(radius: 0.5)
        })
        .buttonStyle(PlainButtonStyle()) 
    }
}

#Preview {
    NavigationCapsule(model: DatabaseHomeViewModel(), title: "Title", image: "key.fill", count: "1", imageBackgroundColor: .blue, destination: .allEntries)
}
