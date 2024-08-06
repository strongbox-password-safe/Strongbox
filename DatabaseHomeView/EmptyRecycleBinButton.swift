//
//  EmptyRecycleBinButton.swift
//  Strongbox
//
//  Created by Strongbox on 03/08/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct EmptyRecycleBinButton: View {
    var model: DatabaseHomeViewModel

    var body: some View {
        Button(role: .destructive, action: {
            Task {
                await model.emptyRecycleBin()
            }
        }) {
            HStack {
                Text("browse_vc_action_empty_recycle_bin")
                Image(systemName: "arrow.3.trianglepath")
            }
        }
    }
}

#Preview {
    EmptyRecycleBinButton(model: DatabaseHomeViewModel())
}
