//
//  AuditNavigationLink.swift
//  Strongbox
//
//  Created by Strongbox on 31/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct AuditNavigationLink<Content: View>: View {
    var title: LocalizedStringKey
    var count: LocalizedStringKey

    @ViewBuilder
    var content: Content

    var body: some View {
        NavigationLink(destination: content) {
            HStack {
                Image(systemName: "checkmark.shield")
                    .foregroundColor(.orange)

                Text(title)

                Spacer()

                Text(count)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    AuditNavigationLink<EmptyView>(title: "Test Title", count: "25") {
        EmptyView()
    }
}
