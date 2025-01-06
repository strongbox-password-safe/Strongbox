//
//  WatchHomeScreen.swift
//  Strongbox
//
//  Created by Strongbox on 19/12/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import OrderedCollections
import SwiftUI

struct Watch2FACodeOnlyView: View {
    @EnvironmentObject
    var model: WatchAppModel
    var entry: WatchEntry
    var database: WatchDatabaseModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.title)
                    .font(.body).bold()
                    .lineLimit(1)

                let effectiveUser = entry.username.isEmpty ? entry.email : entry.username

                if !effectiveUser.isEmpty {
                    let userView = Text(effectiveUser)
                        .font(.caption2)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if model.settings.pro {
                        userView
                    } else {
                        HStack {
                            ProBadge()

                            userView.blur(radius: 3)
                        }
                    }
                }
            }

            HStack {
                WatchListItemIconView(entry: entry, database: database)

                Spacer()

                if let otpAuthUrl = entry.twoFaOtpAuthUrl, let token = OTPToken(url: URL(string: otpAuthUrl)) {
                    WatchTwoFactorAuthDigitsView(totp: token, easyReadSeparator: model.settings.twoFactorEasyReadSeparator)

                    Spacer()

                    TwoFactorCodeCircularProgressView(totp: token, radius: 28, updateMode: .automatic, hideCountdownDigits: model.settings.twoFactorHideCountdownDigits)
                        .padding(2)
                        .frame(width: 28)
                }
            }
        }
    }
}

struct Watch2FACodesOnlyView: View {
    @EnvironmentObject
    var model: WatchAppModel

    var body: some View {
        List {
            ForEach(model.entryList.keys.elements) { database in
                if let entries = model.entryList[database] {
                    let twoFaOnly = entries.filter { $0.twoFaOtpAuthUrl != nil }

                    ForEach(twoFaOnly) { entry in
                        
                        
                        
                        
                        Watch2FACodeOnlyView(entry: entry, database: database)
                        
                    }
                }
            }
        }
    }
}

struct WatchHomeScreen: View {
    @EnvironmentObject
    var model: WatchAppModel

    var has2FACodes: Bool {
        allEntries.first { $0.twoFaOtpAuthUrl != nil } != nil
    }

    var allEntries: [WatchEntry] {
        model.entryList.values.flatMap { $0 }
    }

    var body: some View {
        if model.entryList.keys.elements.isEmpty {
            WatchEmptyView()
        } else {
            TabView {
                NavigationView {
                    WatchEntryListView()
                        .navigationTitle("Strongbox")
                }

                if has2FACodes {
                    NavigationView {
                        Watch2FACodesOnlyView()
                            .navigationTitle("browse_prefs_view_as_totp_list")
                    }
                }
            }
        }
    }
}

#Preview {
    WatchHomeScreen()
        .environmentObject(WatchAppModel())
}
