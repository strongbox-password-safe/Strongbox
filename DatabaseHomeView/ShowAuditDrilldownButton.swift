//
//  ShowAuditDrilldownButton.swift
//  Strongbox
//
//  Created by Strongbox on 30/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct ShowAuditDrilldownButton: View {
    var model: DatabaseHomeViewModel
    var entry: any SwiftEntryModelInterface

    var body: some View {
        Button(action: {
            model.showAuditDrillDown(entry: entry)
        }) {
            HStack {
                Text("view_audit_issue_details_ellipsis")
                Image(systemName: "checkmark.shield")
                    .foregroundColor(.orange)
            }
        }
    }
}

#Preview {
    ShowAuditDrilldownButton(model: DatabaseHomeViewModel(), entry: SwiftDummyEntryModel())
}
