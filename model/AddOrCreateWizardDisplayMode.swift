//
//  AddOrCreateWizardDisplayMode.swift
//  Strongbox
//
//  Created by Strongbox on 17/08/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

enum AddOrCreateWizardDisplayMode {
    case passkey
    case totp

    var itemName: LocalizedStringKey {
        switch self {
        case .passkey:
            "generic_noun_passkey"
        case .totp:
            "generic_fieldname_totp"
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .passkey:
            "passkey_new_passkey_title"
        case .totp:
            "totp_new_passkey_title"
        }
    }

    var overwriteQuestion: LocalizedStringKey {
        switch self {
        case .passkey:
            "passkey_overwrite_question_title"
        case .totp:
            "totp_overwrite_question_title"
        }
    }

    var addExistingTitle: LocalizedStringKey {
        #if os(iOS)
            switch self {
            case .passkey:
                "passkey_select_existing_entry"
            case .totp:
                "totp_select_existing_entry"
            }
        #else
            "add_to_entry_or_create_new"
        #endif
    }










    var overwriteQuestionMsgFmt: String {
        switch self {
        case .passkey:
            NSLocalizedString("passkey_overwrite_existing_question_msg_fmt", comment: "")
        case .totp:
            NSLocalizedString("totp_overwrite_existing_question_msg_fmt", comment: "")
        }
    }

    var questionMsgFmt: String {
        switch self {
        case .passkey:
            NSLocalizedString("passkeys_are_you_sure_add_to_fmt", comment: "Are you sure you want to add this passkey to '%@'?")
        case .totp:
            NSLocalizedString("totps_are_you_sure_add_to_fmt", comment: "Are you sure you want to add this 2FA Code to '%@'?")
        }
    }

    var createSubtitle: LocalizedStringKey {
        switch self {
        case .passkey:
            "passkey_new_entry_text"
        case .totp:
            "totp_new_entry_text"
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .passkey:
            "passkey_how_to_add_to_database"
        case .totp:
            "totp_how_to_add_to_database"
        }
    }

    var icon: String {
        switch self {
        case .passkey:
            "person.badge.key.fill"
        case .totp:
            "timer"
        }
    }
}
