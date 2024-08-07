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

    static let BodyPointSize: CGFloat = NSFont.preferredFont(forTextStyle: .body).pointSize

    static let Caption1PointSize: CGFloat = NSFont.preferredFont(forTextStyle: .caption1).pointSize

    static let HeadLinePointSize: CGFloat = NSFont.preferredFont(forTextStyle: .headline).pointSize

    static let LargeTitlePointSize: CGFloat = NSFont.preferredFont(forTextStyle: .largeTitle).pointSize

    @objc
    let easyReadFont: NSFont = .init(name: EasyReadFontName, size: BodyPointSize) ?? NSFont.systemFont(ofSize: BodyPointSize)

    @objc
    let largeTextEasyReadFont: NSFont = .init(name: EasyReadFontName, size: LargeTitlePointSize) ?? NSFont.systemFont(ofSize: LargeTitlePointSize)

    @objc
    let bodyFont: NSFont = .preferredFont(forTextStyle: .body)

    @objc
    let italicBodyFont: NSFont = {
        let bodyFont = NSFont.preferredFont(forTextStyle: .body)

        let ret = NSFontManager.shared.convert(bodyFont, toHaveTrait: .italicFontMask)

        return ret
    }()

    @objc
    let boldBodyFont: NSFont = {
        let bodyFont = NSFont.preferredFont(forTextStyle: .body)

        let ret = NSFontManager.shared.convert(bodyFont, toHaveTrait: .boldFontMask)
        return ret
    }()

    @objc
    let headlineFont: NSFont = .preferredFont(forTextStyle: .headline)

    @objc
    let headlineItalicFont: NSFont = {
        let font = NSFont.preferredFont(forTextStyle: .headline)

        let ret = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)

        return ret
    }()

    @objc
    let entryTitleFont: NSFont = .systemFont(ofSize: HeadLinePointSize, weight: .semibold)

    @objc
    let caption1Font: NSFont = .preferredFont(forTextStyle: .caption1)

    @objc
    let boldCaption1Font: NSFont = {
        let base = NSFont.preferredFont(forTextStyle: .caption1)

        let ret = NSFontManager.shared.convert(base, toHaveTrait: .boldFontMask)
        return ret
    }()

    @objc
    let boldLargeTitleFont: NSFont = {
        let bodyFont = NSFont.preferredFont(forTextStyle: .largeTitle)

        let ret = NSFontManager.shared.convert(bodyFont, toHaveTrait: .boldFontMask)
        return ret
    }()
}
