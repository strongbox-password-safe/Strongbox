//
//  FontManager.swift
//  MacBox
//
//  Created by Strongbox on 02/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class FontManager: NSObject {
    @objc
    static let shared = FontManager()

    static let EasyReadFontName: String = "Menlo"

    static let BodyPointSize: CGFloat = {
        let pointSize: CGFloat
        if #available(macOS 11.0, *) {
            pointSize = NSFont.preferredFont(forTextStyle: .body).pointSize
        } else {
            pointSize = 13.0
        }

        return pointSize
    }()

    static let Caption1PointSize: CGFloat = {
        let pointSize: CGFloat
        if #available(macOS 11.0, *) {
            pointSize = NSFont.preferredFont(forTextStyle: .caption1).pointSize
        } else {
            pointSize = 11.0
        }

        return pointSize
    }()

    static let HeadLinePointSize: CGFloat = {
        let pointSize: CGFloat
        if #available(macOS 11.0, *) {
            pointSize = NSFont.preferredFont(forTextStyle: .headline).pointSize
        } else {
            pointSize = 13.0
        }

        return pointSize
    }()

    static let LargeTitlePointSize: CGFloat = {
        let pointSize: CGFloat
        if #available(macOS 11.0, *) {
            pointSize = NSFont.preferredFont(forTextStyle: .largeTitle).pointSize
        } else {
            pointSize = 32
        }

        return pointSize
    }()

    @objc
    let easyReadFont: NSFont = {





        NSFont(name: EasyReadFontName, size: BodyPointSize) ?? NSFont.systemFont(ofSize: BodyPointSize)

    }()

    @objc
    let largeTextEasyReadFont: NSFont = {





        NSFont(name: EasyReadFontName, size: LargeTitlePointSize) ?? NSFont.systemFont(ofSize: LargeTitlePointSize)

    }()

    @objc
    let bodyFont: NSFont = {
        if #available(macOS 11.0, *) {
            return NSFont.preferredFont(forTextStyle: .body)
        } else {
            return NSFont.systemFont(ofSize: BodyPointSize)
        }
    }()

    @objc
    let italicBodyFont: NSFont = {
        let bodyFont: NSFont

        if #available(macOS 11.0, *) {
            bodyFont = NSFont.preferredFont(forTextStyle: .body)
        } else {
            bodyFont = NSFont.systemFont(ofSize: BodyPointSize)
        }

        let ret = NSFontManager.shared.convert(bodyFont, toHaveTrait: .italicFontMask)
        return ret
    }()

    @objc
    let boldBodyFont: NSFont = {
        let bodyFont: NSFont

        if #available(macOS 11.0, *) {
            bodyFont = NSFont.preferredFont(forTextStyle: .body)
        } else {
            bodyFont = NSFont.systemFont(ofSize: BodyPointSize)
        }

        let ret = NSFontManager.shared.convert(bodyFont, toHaveTrait: .boldFontMask)
        return ret
    }()

    @objc
    let headlineFont: NSFont = {
        if #available(macOS 11.0, *) {
            return NSFont.preferredFont(forTextStyle: .headline)
        } else {
            return NSFont.systemFont(ofSize: HeadLinePointSize)
        }
    }()

    @objc
    let headlineItalicFont: NSFont = {
        let font: NSFont

        if #available(macOS 11.0, *) {
            font = NSFont.preferredFont(forTextStyle: .headline)
        } else {
            font = NSFont.systemFont(ofSize: HeadLinePointSize)
        }

        let ret = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)

        return ret
    }()

    @objc
    let caption1Font: NSFont = {
        if #available(macOS 11.0, *) {
            return NSFont.preferredFont(forTextStyle: .caption1)
        } else {
            return NSFont.systemFont(ofSize: Caption1PointSize)
        }
    }()
}
