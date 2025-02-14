//
//  TechnicalDetailRow.swift
//  Strongbox
//
//  Created by Strongbox on 27/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation
import SwiftUI

struct TechnicalDetailRow: View {
    var key: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(key)
                .font(.body)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
        }
    }
}























