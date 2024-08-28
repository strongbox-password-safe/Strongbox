//
//  BrowseViewColumn.swift
//  MacBox
//
//  Created by Strongbox on 26/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Foundation

enum BrowseViewColumn: String, CaseIterable {
    case title = "TitleColumn"
    case username = "UsernameColumn"
    case password = "PasswordColumn"
    case url = "URLColumn"
    case email = "EmailColumn"
    case notes = "NotesColumn"
    case created = "CreatedColumn"
    case modified = "ModifiedColumn"
    case expires = "ExpiresColumn"
    case totp = "TOTPColumn"
    case attachmentCount = "AttachmentCountColumn"
    case customFieldCount = "CustomFieldCountColumn"
    case tags = "TagsColumn"
    case path = "PathColumn"
    case historicalItemCount = "HistoricalItemCountColumn"
    case customIcon = "CustomIconColumn"
    case uuid = "UuidColumn"
    case auditIssues = "AuditIsssuesColumn"
    case customIconSize = "CustomIconSize"
    case size = "Size"

    var identifier: NSUserInterfaceItemIdentifier {
        NSUserInterfaceItemIdentifier(rawValue)
    }

    var initialSize: CGFloat {
        switch self {
        case .title:
            return 175
        case .username:
            return 100
        default:
            return 150
        }
    }

    var visibleByDefault: Bool {
        switch self {
        case .title:
            return true
        case .username:
            return true
        case .password:
            return false
        case .url:
            return true
        case .email:
            return false
        case .notes:
            return false
        case .created:
            return false
        case .modified:
            return true
        case .expires:
            return false
        case .totp:
            return false
        case .attachmentCount:
            return false
        case .customFieldCount:
            return false
        case .tags:
            return false
        case .path:
            return false
        case .historicalItemCount:
            return false
        case .customIcon:
            return false
        case .uuid:
            return false
        case .auditIssues:
            return false
        case .customIconSize:
            return false
        case .size:
            return false
        }
    }

    var title: String {
        switch self {
        case .title:
            return NSLocalizedString("generic_fieldname_title", comment: "Title")
        case .username:
            return NSLocalizedString("generic_fieldname_username", comment: "Username")
        case .password:
            return NSLocalizedString("generic_fieldname_password", comment: "Password")
        case .url:
            return NSLocalizedString("generic_fieldname_url", comment: "URL")
        case .email:
            return NSLocalizedString("generic_fieldname_email", comment: "Email")
        case .notes:
            return NSLocalizedString("generic_fieldname_notes", comment: "Notes")
        case .created:
            return NSLocalizedString("item_details_metadata_created_field_title", comment: "Created")
        case .modified:
            return NSLocalizedString("item_details_metadata_modified_field_title", comment: "Modified")
        case .expires:
            return NSLocalizedString("generic_fieldname_expiry_date", comment: "Expiry Date")
        case .totp:
            return NSLocalizedString("generic_fieldname_totp", comment: "2FA")
        case .attachmentCount:
            return NSLocalizedString("generic_fieldname_attachments", comment: "Attachments")
        case .customFieldCount:
            return NSLocalizedString("generic_fieldname_custom_fields", comment: "Custom Fields")
        case .tags:
            return NSLocalizedString("generic_fieldname_tags", comment: "Tags")
        case .path:
            return NSLocalizedString("generic_fieldname_location", comment: "Location")
        case .historicalItemCount:
            return NSLocalizedString("generic_fieldname_historical_item_count", comment: "Historical Item Count")
        case .customIcon:
            return NSLocalizedString("generic_fieldname_custom_icon", comment: "Custom Icon")
        case .uuid:
            return NSLocalizedString("generic_fieldname_id", comment: "ID")
        case .auditIssues:
            return NSLocalizedString("browse_vc_action_audit", comment: "Audit")
        case .customIconSize:
            return NSLocalizedString("generic_fieldname_custom_icon_size", comment: "Custom Icon Size")
        case .size:
            return NSLocalizedString("generic_fieldname_estimated_size", comment: "Estimated Size")
        }
    }
}
