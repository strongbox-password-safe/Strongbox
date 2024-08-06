//
//  AttachmentTableCellView.swift
//  MacBox
//
//  Created by Strongbox on 20/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class AttachmentTableCellView: NSTableCellView, DetailTableCellViewPopupButton, NSMenuDelegate {
    @IBOutlet var imagePreview: NSImageView!
    @IBOutlet var labelFileSize: NSTextField!
    @IBOutlet var labelFileName: NSTextField!
    @IBOutlet var popupButton: NSButton!

    override func prepareForReuse() {
        super.prepareForReuse()

        imagePreview.image = NSImage(named: "document_empty_64")
        labelFileName.stringValue = "<Not Set>"
        labelFileSize.stringValue = "<Not Set>"
    }

    var popupMenuUpdater: ((NSMenu, DetailsViewField) -> Void)?
    var field: DetailsViewField?

    func setContent(_ field: DetailsViewField, popupMenuUpdater: ((NSMenu, DetailsViewField) -> Void)? = nil) {
        self.field = field
        self.popupMenuUpdater = popupMenuUpdater
        popupButton.menu?.delegate = self

        guard let attachment = field.object as? KeePassAttachmentAbstractionLayer else {
            swlog("🔴 Couldn't get attachment from field")
            return
        }

        let fileSize = friendlyFileSizeString(Int64(attachment.length))
        let previewImage = AttachmentPreviewHelper.shared.getPreviewImage(field.name, attachment)

        imagePreview.image = previewImage ?? NSImage(named: "document_empty_64")
        labelFileName.stringValue = field.name
        labelFileSize.stringValue = fileSize
    }

    func showPopupButtonMenu() {
        swlog("✅ showPopupButton")

        popupButton.performClick(nil)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {


        guard let field else {
            return
        }

        popupMenuUpdater?(menu, field)
    }
}
