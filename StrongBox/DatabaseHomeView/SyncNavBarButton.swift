//
//  SyncNavBarButton.swift
//  Strongbox
//
//  Created by Strongbox on 02/08/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct SyncNavBarButton: View {
    @State private var isAnimating = false
    @State private var isError = false

    var show: Bool {
        if let syncStatus = model.syncStatus, syncStatus.state == .inProgress || syncStatus.state == .error {
            return true
        }

        if model.isRunningAsyncUpdate {
            return true
        }

        if let result = model.lastAsyncUpdateResult, !result.success {
            return true
        }

        return false
    }

    var foreverAnimation: Animation {
        Animation.linear(duration: 1.0)
            .repeatForever(autoreverses: false)
    }

    @ObservedObject
    var model: DatabaseHomeViewModel

    func updateState() {
        isAnimating = model.syncStatus?.state == .some(.inProgress) || model.isRunningAsyncUpdate
        isError = model.syncStatus?.state == .some(.error) || !(model.lastAsyncUpdateResult?.success ?? true)
    }

    var body: some View {
        Button(action: {}, label: {
            if show {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundColor(isError ? .red : .blue)
                    .rotationEffect(Angle(degrees: isAnimating ? 360 : 0.0))
                    .animation(isAnimating ? foreverAnimation : .default, value: isAnimating)
            }
        })
        .onAppear {
            updateState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .asyncUpdateDone, object: nil)) { _ in
            updateState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .asyncUpdateDone, object: nil)) { _ in
            updateState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .syncManagerDatabaseSyncStatusChanged, object: nil)) { _ in
            updateState()
        }
    }
}

#Preview {
    let model = DatabaseHomeViewModel(externalWorldAdaptor: DummyDatabaseActionsInterface(isRunningAsyncUpdate: true))

    return NavigationView {
        Text("Test")
            .navigationTitle("Testing")
            .navigationBarItems(leading: SyncNavBarButton(model: model))
    }
}
