//
//  SBDownTextView.swift
//  Strongbox
//
//  Created by Strongbox on 28/09/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//
// Modified from original https://github.com/johnxnguyen/Down

import Foundation
import Down

@objc class SBDownTextView : TextView {
    @objc var markdownEnabled : Bool = false {
        didSet {
            guard oldValue != markdownEnabled else { return }
            
            try? render()
        }
    }

    #if canImport(UIKit)
    
    open override var text: String! {
        didSet {
            guard oldValue != text else { return }
            try? render()
        }
    }

    #elseif canImport(AppKit)

    open override var string: String {
        didSet {
            guard oldValue != string else { return }
            try? render()
        }
    }

    #endif

    

    var colorCollection : ColorCollection {
        get {
            if #available(iOS 13.0, macOS 11.0, *)  {
                return SBColorCollection()
            }
            else {
                return StaticColorCollection()
            }
        }
    }
    
    var fontCollection : FontCollection {
        get {
            if #available(iOS 13.0, macOS 11.0, *)  {
                return StrongboxFontCollection()
            }
            else {
                return StaticFontCollection()
            }
        }
    }

    var styler : DownStyler {
        get {
            return DownStyler(configuration: DownStylerConfiguration(fonts: fontCollection, colors : colorCollection ))
        }
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        
        #if os(macOS)
        if #available(OSX 10.14, *) {
            usesAdaptiveColorMappingForDarkAppearance = true
        }
        #endif
    }
    
    #if os(iOS)
    @objc convenience public init(frame: CGRect) {
        self.init(frame: frame, layoutManager: DownLayoutManager ())
    }
    #endif
    
    public init(frame: CGRect, layoutManager: NSLayoutManager) {
        let textStorage = NSTextStorage()
        let textContainer = NSTextContainer()

        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        super.init(frame: frame, textContainer: textContainer)

        
        
        linkTextAttributes = [:]
        #if os(macOS)
        if #available(OSX 10.14, *) {
            usesAdaptiveColorMappingForDarkAppearance = true
        }
        #endif
    }
    
    func render() throws {
        #if canImport(UIKit)
        let down = Down(markdownString: text)
        let markdown = try down.toAttributedString([.hardBreaks, .smart], styler: styler) 
        
        if ( markdownEnabled ) {
            attributedText = markdown
        }




        
        #elseif canImport(AppKit)
        guard let textStorage = textStorage else { return }
                
        if ( markdownEnabled ) {
            let down = Down(markdownString: string)
            let markdown = try down.toAttributedString([.hardBreaks, .smart], styler: styler) 

            textStorage.setAttributedString(markdown)
        }
        else {
            let tmp = NSAttributedString(string: string);
            textStorage.setAttributedString(tmp)
        }
        
        #endif
    }
}
