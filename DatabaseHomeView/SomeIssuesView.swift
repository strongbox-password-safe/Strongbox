//
//  SomeIssuesView.swift
//  Strongbox
//
//  Created by Strongbox on 07/08/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct SomeIssuesView: View {
    @ObservedObject
    var model: DatabaseHomeViewModel

    var body: some View {
        let auditModel = model.auditModel

        List {
            let noPasswords = auditModel.noPasswords.count
            if noPasswords > 0 {
                Section {
                    AuditNavigationLink(title: "audit_quick_summary_very_brief_no_password_set", count: .init(String(noPasswords))) {
                        AuditSimpleListView(model: model, title: "audit_quick_summary_very_brief_no_password_set", list: auditModel.noPasswords)
                    }
                } footer: {
                    Text("audit_view_section_footer_no_password")
                }
            }

            let dupeCount = auditModel.duplicateEntryCount
            if dupeCount > 0 {
                Section {
                    AuditNavigationLink(title: "audit_quick_summary_very_brief_duplicated_password", count: .init(String(dupeCount))) {
                        AuditGroupedDupesOrSimilarView(model: model, viewMode: .duplicates)
                    }
                } footer: {
                    Text("audit_view_section_footer_duplicate")
                }
            }

            let common = auditModel.common.count
            if common > 0 {
                Section {
                    AuditNavigationLink(title: "audit_quick_summary_very_brief_very_common_password", count: .init(String(common))) {
                        AuditSimpleListView(model: model, title: "audit_quick_summary_very_brief_very_common_password", list: auditModel.common)
                    }
                } footer: {
                    Text("audit_view_section_footer_common")
                }
            }

            let similar = auditModel.similarEntryCount
            if similar > 0 {
                Section {
                    AuditNavigationLink(title: "audit_quick_summary_very_brief_password_is_similar_to_another", count: .init(String(similar))) {
                        AuditGroupedDupesOrSimilarView(model: model, viewMode: .similar)
                    }
                } footer: {
                    Text("audit_view_section_footer_similar")
                }
            }

            let tooShort = auditModel.tooShort.count
            if tooShort > 0 {
                Section {
                    AuditNavigationLink(title: "audit_quick_summary_very_brief_password_is_too_short", count: .init(String(tooShort))) {
                        AuditSimpleListView(model: model, title: "audit_quick_summary_very_brief_password_is_too_short", list: auditModel.tooShort)
                    }
                } footer: {
                    Text("audit_view_section_footer_short")
                }
            }

            let pwned = auditModel.pwned.count
            if pwned > 0 {
                Section {
                    AuditNavigationLink(title: "audit_quick_summary_very_brief_password_is_pwned", count: .init(String(pwned))) {
                        AuditSimpleListView(model: model, title: "audit_quick_summary_very_brief_password_is_pwned", list: auditModel.pwned)
                    }
                } footer: {
                    Text("audit_view_section_footer_hibp")
                }
            }

            let lowEntropy = auditModel.lowEntropy.count
            if lowEntropy > 0 {
                Section {
                    AuditNavigationLink(title: "audit_quick_summary_very_brief_low_entropy", count: .init(String(lowEntropy))) {
                        AuditSimpleListView(model: model, title: "audit_quick_summary_very_brief_low_entropy", list: auditModel.lowEntropy)
                    }
                } footer: {
                    Text("audit_view_section_footer_entropy")
                }
            }

            let twoFactorAvailable = auditModel.twoFactorAvailable.count
            if twoFactorAvailable > 0 {
                Section {
                    AuditNavigationLink(title: "audit_quick_summary_very_brief_two_factor_available", count: .init(String(twoFactorAvailable))) {
                        AuditSimpleListView(model: model, title: "audit_quick_summary_very_brief_two_factor_available", list: auditModel.twoFactorAvailable)
                    }
                } footer: {
                    Text("audit_view_section_footer_2fa")
                }
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
        SomeIssuesView(model: DatabaseHomeViewModel(database: db))
    }
}
