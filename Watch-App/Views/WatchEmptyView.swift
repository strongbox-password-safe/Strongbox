//
//  WatchEmptyView.swift
//  Strongbox
//
//  Created by Strongbox on 19/12/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import OrderedCollections
import SwiftUI

struct WatchEmptyView: View {
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(.blue)
                    .frame(width: 38)

                Image(systemName: "lock.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.white)
            }

            VStack {
                Text("watch_empty_nothing_here_yet")
                    .font(.headline)
                    .lineLimit(1)

                Text("watch_empty_instructions")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

#Preview {
    WatchEmptyView()
}
