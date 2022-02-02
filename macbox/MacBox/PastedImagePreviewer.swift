//
//  PastedImagePreviewer.swift
//  MacBox
//
//  Created by Strongbox on 04/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class PastedImagePreviewer: NSViewController, NSWindowDelegate {
    class func fromStoryboard() -> Self {
        let storyboard = NSStoryboard(name: "PastedImagePreviewer", bundle: nil)
        return storyboard.instantiateInitialController() as! Self
    }

    var image: NSImage!
    @IBOutlet var imageView: NSImageView!

    let autosave: String = "PastedImagePreviewerAutoSave"

    func windowDidEndLiveResize(_: Notification) {
        view.window?.saveFrame(usingName: autosave)
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        guard let window = view.window else {
            return
        }

        window.delegate = self
        window.setFrameUsingName(NSWindow.FrameAutosaveName(autosave))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        imageView.image = image
    }

    var onGo: (() -> Void)!

    @IBAction func onGoButton(_: Any) {
        dismiss(nil)

        onGo()
    }

    @IBAction func onDismiss(_: Any) {
        dismiss(nil)
    }
}
