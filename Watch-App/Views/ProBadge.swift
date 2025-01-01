//
//  ProBadge.swift
//  Strongbox
//
//  Created by Strongbox on 15/12/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct ProBadge: View {
    var body: some View {
        Text("Pro")
            .font(.system(size: 14))
            .bold()
            .padding(.horizontal)
            .lineLimit(1)
            .background(.blue)
            .clipShape(.capsule)
    }
}
