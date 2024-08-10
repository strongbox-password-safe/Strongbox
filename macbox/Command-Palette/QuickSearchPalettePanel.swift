//
//  QuickSearchPalettePanel.swift
//  MacBox
//
//  Created by Strongbox on 16/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation

class QuickSearchPalettePanel: NSPanel {
    static let InitialRect = CGRect(x: 0, y: 0, width: 820, height: 40)

    static let StyleMask: StyleMask = [.closable, .titled, .nonactivatingPanel, .fullSizeContentView, .resizable]

    let model: QuickSearchViewModel

    init(model: QuickSearchViewModel) {
        self.model = model

        super.init(contentRect: Self.InitialRect, styleMask: Self.StyleMask, backing: .buffered, defer: false)

        minSize = CGSize(width: 400, height: 40)

        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        worksWhenModal = true
        level = .modalPanel
        isReleasedWhenClosed = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        animationBehavior = .utilityWindow
        isOpaque = false

        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        collectionBehavior.insert(.fullScreenAuxiliary)
        collectionBehavior.insert(.canJoinAllSpaces)

        let vc = QuickSearchPaletteViewController.instantiateFromStoryboard()
        vc.model = model
        contentViewController = vc

        center() 
    }

    override func cancelOperation(_ sender: Any?) {
        super.cancelOperation(sender)

        hidePalette()
    }

    override var canBecomeKey: Bool { true }

    override func resignKey() {
        super.resignKey()

        hidePalette()
    }

    func toggleShow() {
        if isVisible {
            hidePalette()
        } else {
            showPalette()
        }
    }

    func showPalette() {
        orderFrontRegardless()

        makeKey()
    }

    func hidePalette() {
        orderOut(nil)
    }
}
