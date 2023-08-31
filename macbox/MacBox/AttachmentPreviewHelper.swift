//
//  AttachmentPreviewHelper.swift
//  MacBox
//
//  Created by Strongbox on 20/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class AttachmentPreviewHelper {
    static let shared = AttachmentPreviewHelper()

    private init() {}

    var cache: [String: NSImage] = [:]
    func getPreviewImage(_ filename: String, _ attachment: KeePassAttachmentAbstractionLayer) -> NSImage? {
        if let cached = cache[attachment.digestHash] {

            return cached
        }

        let MaxLoadBytes = 3 * 1024 * 1024

        if attachment.length > MaxLoadBytes {
            let ret = NSWorkspace.shared.icon(forFileType: filename)
            cache[attachment.digestHash] = ret
            return ret
        }

        let data = attachment.nonPerformantFullData

        if let fullSize = NSImage(data: data),
           let thumbnail = thumbnailImageFromImage(image: fullSize, maximumSize: NSMakeSize(128, 128))
        {
            cache[attachment.digestHash] = thumbnail
            return thumbnail
        } else {
            let ret = NSWorkspace.shared.icon(forFileType: filename)
            cache[attachment.digestHash] = ret
            return ret
        }
    }

    private func thumbnailImageFromImage(image: NSImage, maximumSize: NSSize) -> NSImage? {
        guard image.isValid else {
            return nil
        }

        let imageSize = image.size
        let imageAspectRatio = min(maximumSize.width / imageSize.width, maximumSize.height / imageSize.height)
        let thumbnailSize = NSSize(width: imageAspectRatio * imageSize.width, height: imageAspectRatio * imageSize.height)
        let thumbnailImage = NSImage(size: thumbnailSize)

        guard thumbnailImage.isValid else {
            return nil
        }

        thumbnailImage.lockFocus()
        image.draw(in: NSRect(x: 0, y: 0, width: thumbnailSize.width, height: thumbnailSize.height),
                   from: NSRect.zero,
                   operation: .sourceOver,
                   fraction: 1.0)
        thumbnailImage.unlockFocus()

        return thumbnailImage
    }
}
