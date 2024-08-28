//
//  AuditNavigationView.swift
//  Strongbox
//
//  Created by Strongbox on 31/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct AuditNavigationView: View {
    @ObservedObject
    var model: DatabaseHomeViewModel
    var showCloseButton: Bool = true

    var isEnabled: Bool {
        model.auditModel.isEnabled
    }

    var isInProgress: Bool {
        model.auditModel.isInProgress
    }

    @State
    var auditProgress: Double = 0.0

    var body: some View {
        Group {
            if isEnabled {
                if isInProgress {
                    AuditInProgressView(progress: $auditProgress)
                } else {
                    if model.database.auditIssueEntryCount == 0 {
                        NoIssuesView()
                    } else {
                        SomeIssuesView(model: model)
                    }
                }
            } else {
                AuditDisabledView()
            }
        }
        .animation(.easeOut, value: isInProgress)
        .onAppear(perform: {
            swlog("🐞 AuditNavigationView onAppear")
            model.objectWillChange.send() 
        })
        .onReceive(NotificationCenter.default.publisher(for: .modelEdited, object: nil)) { _ in
            swlog("🐞 AuditNavigationView received modelEdited")
            model.objectWillChange.send() 
        }
        .onReceive(NotificationCenter.default.publisher(for: .databaseUpdated, object: nil)) { _ in
            swlog("🐞 AuditNavigationView received databaseUpdated")
            model.objectWillChange.send() 
        }
        .onReceive(NotificationCenter.default.publisher(for: .auditCompleted, object: nil)) { _ in
            swlog("🐞 AuditNavigationView received auditCompleted")
            model.objectWillChange.send() 
        }
        .onReceive(NotificationCenter.default.publisher(for: .auditProgress, object: nil)) { note in
            guard let progress = note.object as? NSNumber else {
                return
            }

            swlog("🐞 AuditNavigationView received auditProgress \(progress)")

            auditProgress = progress.doubleValue

            model.objectWillChange.send() 
        }
        .onReceive(NotificationCenter.default.publisher(for: .databaseReloaded, object: nil)) { _ in
            swlog("🐞 AuditNavigationView received databaseReloaded")
            model.objectWillChange.send() 
        }
        .navigationTitle("browse_vc_action_audit")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                HStack {
                    if showCloseButton {
                        Button(action: {
                            model.close()
                        }) {
                            Text("generic_verb_close")
                        }
                    }
                }
            }

            ToolbarItem(placement: .principal) {
                HStack(spacing: 2) {
                    let noIssues = !isInProgress && model.database.auditIssueEntryCount == 0

                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(noIssues ? .blue : .orange)
                        .font(.subheadline)

                    Text("browse_vc_action_audit")
                        .lineLimit(1)
                        .font(.headline)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    model.presentAuditSettings()
                }, label: {
                    Image(systemName: "gear")
                })
            }
        }
    }
}

#Preview {
    var db = SwiftDummyDatabaseModel()

    let duplicated = [
        "a2": [
            SwiftDummyEntryModel(title: "Alpha"),
            SwiftDummyEntryModel(title: "Alpha2"),
            SwiftDummyEntryModel(title: "Beta")],
        "a1": [
            SwiftDummyEntryModel(title: "Gamma"),
            SwiftDummyEntryModel(title: "Gamma2"),
            SwiftDummyEntryModel(title: "Delta")],
    ]
    let similar = duplicated

    let samples = [SwiftDummyEntryModel(title: "Gamma"),
                   SwiftDummyEntryModel(title: "Gamma2"),
                   SwiftDummyEntryModel(title: "Delta")]

    db.auditModel = AuditViewModel(duplicated: duplicated, noPasswords: samples, common: samples, similar: similar, tooShort: samples, pwned: samples, lowEntropy: samples, twoFactorAvailable: samples, similarEntryCount: 3, duplicateEntryCount: 3)

    return NavigationView {
        AuditNavigationView(model: DatabaseHomeViewModel(database: db))
    }
}
