//
//  DatabaseHomeViewHeader.swift
//  Strongbox
//
//  Created by Strongbox on 27/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation
import SwiftUI

struct DatabaseHomeViewHeader: View {
    var title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    var image: String
    var imageColor: Color

    var body: some View {
        if #available(iOS 16.0, *) {
            HStack(spacing: 4) {
                Image(systemName: image)
                    .foregroundColor(imageColor)
                    .font(.title3)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .lineLimit(2)
                        .font(.title3)
                        .fontWeight(.bold)

                    if let subtitle {
                        Text(subtitle)
                            .lineLimit(2)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: image)
                    .foregroundColor(imageColor)

                Text(title)
            }
            .font(.title3)
        }
    }
}

#Preview {
    DatabaseHomeViewHeader(title: "generic_noun_navigation", subtitle: "Find your way around your database.", image: "location.fill", imageColor: .purple)
}
