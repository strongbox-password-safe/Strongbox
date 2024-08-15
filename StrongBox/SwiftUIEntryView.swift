//
//  SwiftUIEntryView.swift
//  Strongbox
//
//  Created by Strongbox on 17/09/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import SwiftUI

struct SwiftUIEntryView: View {
    var title: String
    var username: String
    var path: String
    var icon: IMAGE_TYPE_PTR
    var favourite: Bool = false
    var flagged: Bool = true
    var totp: OTPToken? = nil
    var showIcon: Bool = true

    init(title: String, username: String, path: String, icon: IMAGE_TYPE_PTR, favourite: Bool = false, totp: OTPToken? = nil, flagged: Bool = false, showIcon: Bool) {
        self.title = title
        self.username = username
        self.path = path
        self.icon = icon
        self.favourite = favourite
        self.totp = totp
        self.flagged = flagged
        self.showIcon = showIcon
    }

    init(entry: any SwiftEntryModelInterface, showIcon: Bool) {
        self.init(title: entry.title, username: entry.username, path: entry.searchFoundInPath, icon: entry.image, favourite: entry.isFavourite, totp: entry.totp, flagged: entry.isFlaggedByAudit, showIcon: showIcon)
    }

    var body: some View {
        HStack {
            #if os(iOS)
                let img = Image(uiImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundColor(/*@START_MENU_TOKEN@*/ .blue/*@END_MENU_TOKEN@*/)
                    .cornerRadius(3.0)
            #else
                let img = Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundColor(/*@START_MENU_TOKEN@*/ .blue/*@END_MENU_TOKEN@*/)
                    .cornerRadius(3.0)
            #endif

            if showIcon {
                img
            }















            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    HStack(spacing: 1) {
                        if favourite {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                        if flagged {
                            Image(systemName: "checkmark.shield")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }

                    Spacer()

                    if let totp {
                        TotpView(totp: totp)
                            .font(.custom("Menlo", size: 14.0, relativeTo: .caption2))
                    }
                }

                HStack {
                    Text(username)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Text(path)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }
}

#Preview {
    let totp = OTPToken(url: URL(string: "otpauth:

    return List {
        SwiftUIEntryView(title: "Test Title", username: "Username", path: "/Factories/Acme Inc.", icon: NodeIconHelper.defaultIcon, favourite: true, totp: totp, flagged: true, showIcon: true)

        SwiftUIEntryView(title: "Test Title which is quite long and might need to wrap onto a new line or two or to infinity and beyond.", username: "Username", path: "/Factories/Acme Inc.", icon: NodeIconHelper.defaultIcon, showIcon: true)
    }
}
