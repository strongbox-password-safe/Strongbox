//
//  WatchEntryDetailView.swift
//  Strongbox
//
//  Created by Strongbox on 13/12/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import OrderedCollections
import SwiftUI

struct WatchEntryDetailView: View {
    var entry: WatchEntry
    var database: WatchDatabaseModel

    @EnvironmentObject
    var model: WatchAppModel

    var custom: [WatchCustomField] {
        entry.customFields.map { kvp in
            kvp.first!.value
        }
    }

    var body: some View {
        List {
            if !entry.username.isEmpty {
                EntryFieldView(key: "generic_fieldname_username", value: entry.username, pro: model.settings.pro, colorBlind: model.settings.colorBlind)
            }

            if !entry.password.isEmpty {
                EntryFieldView(key: "generic_fieldname_password", value: entry.password, concealed: true, pro: model.settings.pro, colorBlind: model.settings.colorBlind)
            }

            if !entry.email.isEmpty {
                EntryFieldView(key: "generic_fieldname_email", value: entry.email, pro: model.settings.pro, colorBlind: model.settings.colorBlind)
            }

            if let otpAuthUrl = entry.twoFaOtpAuthUrl, let token = OTPToken(url: URL(string: otpAuthUrl)) {
                NavigationLink {
                    WatchTwoFactorAuthLargeTextView(totp: token, easyReadSeparator: model.settings.twoFactorEasyReadSeparator, isPro: model.settings.pro)
                } label: {
                    WatchTwoFactorAuthListItemView(totp: token, easyReadSeparator: model.settings.twoFactorEasyReadSeparator)
                }
            }

            if !entry.url.isEmpty {
                EntryFieldView(key: "generic_fieldname_primary_url", value: entry.url, pro: model.settings.pro, colorBlind: model.settings.colorBlind)
            }

            if !entry.alternativeUrls.isEmpty {
                Section {
                    ForEach(entry.alternativeUrls, id: \.self) { url in
                        EntryFieldView(key: nil, value: url, pro: model.settings.pro, colorBlind: model.settings.colorBlind)
                    }
                }
                header: {
                    Text("generic_fieldname_other_urls")
                }
            }

            if !entry.notes.isEmpty {
                EntryFieldView(key: "generic_fieldname_notes", value: entry.notes, markdown: model.settings.markdownNotes, pro: model.settings.pro, colorBlind: model.settings.colorBlind)
            }

            if !custom.isEmpty {
                Section {
                    ForEach(custom) { theField in
                        EntryFieldView(key: .init(theField.key), value: theField.value, concealed: theField.concealable, pro: model.settings.pro, colorBlind: model.settings.colorBlind)
                    }
                }
                header: {
                    Text("generic_fieldname_custom_fields")
                }
            }
        }
        .navigationTitle(entry.title)
    }
}

#Preview {
    let entry = WatchEntry(title: "Testing Watch App with a Long Title",
                           icon: WatchEntryIcon.preset(icon: 0),
                           username: "username",
                           password: "abc123")

    let database = WatchDatabaseModel(nickName: "Database Name", uuid: "1234", iconSet: KeePassIconSet.sfSymbols.rawValue)

    return WatchEntryDetailView(entry: entry, database: database)
        .environmentObject(WatchAppModel())
}
