//
//  AuditInProgressView.swift
//  Strongbox
//
//  Created by Strongbox on 07/08/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct CircularProgressView: View {
    let progress: Double
    let strokeWidth = 25.0
    var color: Color = .orange

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    color.opacity(0.5),
                    lineWidth: strokeWidth
                )

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: strokeWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut, value: progress)
        }
    }
}



struct AuditInProgressView: View {
    @Binding
    var progress: Double

    var body: some View {
        VStack {
            ZStack {
                CircularProgressView(progress: progress)
                    .padding()

                VStack(spacing: 2) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)

                    Text(String(format: "%0.0f%%", progress * 100))
                        .font(.headline)
                        .bold()
                }
            }.frame(width: 200, height: 200)

            if progress < 1 {
                Text("generic_verb_auditing_in_progress_ellipsis")
                    .font(.title)
            }









        }
    }

    func resetProgress() {
        progress = 0
    }
}

#Preview {
    AuditInProgressView(progress: .constant(0.5))
}
