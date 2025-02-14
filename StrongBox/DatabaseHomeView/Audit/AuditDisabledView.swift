//
//  AuditDisabledView.swift
//  Strongbox
//
//  Created by Strongbox on 07/08/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct AuditDisabledView: View {
    var body: some View {
        VStack {
            Image(systemName: "shield.slash")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("audit_disabled")
                .foregroundStyle(.secondary)
                .font(.title)

            Text("generic_tap_the_settings_button_to_configure")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
    }
}

#Preview {
    AuditDisabledView()
}
