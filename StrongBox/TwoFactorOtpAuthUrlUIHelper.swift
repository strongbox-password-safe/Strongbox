//
//  TwoFactorOtpAuthUrlUIHelper.swift
//  Strongbox
//
//  Created by Strongbox on 16/08/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation
import SwiftUI

@objc
class TwoFactorOtpAuthUrlUIHelper: NSObject {
    enum TFUIError: Error {
        case userCancelled
        case genericError(detail: String)
    }

    @objc
    @MainActor
    class func beginOtpAuthURLImport(url: URL, viewController: UIViewController) async throws -> DatabasePreferences? {
        guard let token = OTPToken(url: url) else {
            swlog("🔴 Could not parse OTPAuth url [%@]", url)
            throw TFUIError.genericError(detail: "This is not a valid OTPAuth URL")
        }

        let writeableDbs = DatabasePreferences.allDatabases.filter { !$0.readOnly }
        guard let first = writeableDbs.first else {
            swlog("🔴 No writeable databases available!")
            throw TFUIError.genericError(detail: "No Writeable Databases Found")
        }

        if DatabasePreferences.allDatabases.count > 1 {
            return try await selectDatabase(token: token, viewController: viewController)
        } else {
            return first
        }
    }

    @MainActor
    class func selectDatabase(token _: OTPToken, viewController: UIViewController) async throws -> DatabasePreferences? {
        let nav = SelectDatabaseViewController.fromStoryboard()

        guard let vc = nav.topViewController as? SelectDatabaseViewController else {
            throw TFUIError.genericError(detail: "Couldn't create select database UI!")
        }

        vc.disableReadOnlyDatabases = true
        vc.customTitle = NSLocalizedString("select_database_to_save_2fa_code_title", comment: "Select Database for 2FA Code")

        async let foo = withCheckedContinuation { continuation in
            Task { @MainActor in
                vc.onSelectedDatabase = { database, _ in
                    viewController.dismiss(animated: true) {
                        continuation.resume(returning: database)
                    }
                }
            }
        }

        viewController.present(nav, animated: true)

        let ret = await foo

        guard let ret else {
            return .none
        }

        return .some(ret)
    }
}
