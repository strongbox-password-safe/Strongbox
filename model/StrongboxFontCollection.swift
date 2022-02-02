//
//  StrongboxFontCollection.swift
//  Strongbox
//
//  Created by Strongbox on 28/09/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Down
import Foundation

extension DownFont {
    func withTraits(traits: DownFontDescriptor.SymbolicTraits) -> DownFont? {
        let descriptor = fontDescriptor.withSymbolicTraits(traits)

        #if os(iOS)
            return DownFont(descriptor: descriptor!, size: 0) 
        #else
            return DownFont(descriptor: descriptor, size: 0)
        #endif
    }

    func bold() -> DownFont? {
        #if os(iOS)
            return withTraits(traits: .traitBold)
        #else
            return withTraits(traits: .bold)
        #endif
    }

    func italic() -> DownFont? {
        #if os(iOS)
            return withTraits(traits: .traitItalic)
        #else
            return withTraits(traits: .italic)
        #endif
    }
}


@available(macOS 11.0, *)
@available(iOS 11.0, *)




public struct StrongboxFontCollection: FontCollection {
    

    public var heading1: DownFont
    public var heading2: DownFont
    public var heading3: DownFont
    public var heading4: DownFont
    public var heading5: DownFont
    public var heading6: DownFont
    public var body: DownFont
    public var code: DownFont
    public var listItemPrefix: DownFont

    

    public init(
        heading1: DownFont = .preferredFont(forTextStyle: .largeTitle),
        heading2: DownFont = .preferredFont(forTextStyle: .title1), 
        heading3: DownFont = .preferredFont(forTextStyle: .title2), 
        heading4: DownFont = .preferredFont(forTextStyle: .title3), 
        heading5: DownFont = .preferredFont(forTextStyle: .headline), 
        heading6: DownFont = .preferredFont(forTextStyle: .subheadline), 
        body: DownFont = .preferredFont(forTextStyle: .body),
        code _: DownFont = DownFont(name: "menlo", size: 17) ?? .systemFont(ofSize: 17),
        listItemPrefix _: DownFont = DownFont.monospacedDigitSystemFont(ofSize: 17, weight: .regular)
    ) {
        let fallback = DownFont.systemFont(ofSize: 17)

        self.heading1 = heading1.bold() ?? fallback
        self.heading2 = heading2.bold() ?? fallback
        self.heading3 = heading3.bold() ?? fallback
        self.heading4 = heading4.bold() ?? fallback
        self.heading5 = heading5.bold() ?? fallback
        self.heading6 = heading6.bold() ?? fallback

        self.body = body
        let bodyPointSize = body.pointSize
        code = DownFont(name: "menlo", size: bodyPointSize) ?? .systemFont(ofSize: bodyPointSize)
        listItemPrefix = DownFont.monospacedDigitSystemFont(ofSize: bodyPointSize, weight: .regular)
    }
}
