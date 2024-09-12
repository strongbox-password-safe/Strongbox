//
//  NoIssuesView.swift
//  Strongbox
//
//  Created by Strongbox on 07/08/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct NoIssuesView: View {
    var body: some View {
        VStack {
            ZStack {
                CircularProgressView(progress: 100, color: .green)
                    .padding()

                Image(systemName: "checkmark.shield")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
            }.frame(width: 200, height: 200)

            Text("audit_complete")
                .font(.title)
            Text("audit_status_no_issues_found")
                .font(.callout)
        }
    }
}

#Preview {
    NoIssuesView()
}
