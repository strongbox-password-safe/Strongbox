//
//  GenericOnboardingVC.swift
//  MacBox
//
//  Created by Strongbox on 19/06/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class GenericOnboardingModule: OnboardingModule {
    var window: NSWindow? = nil
    var shouldDisplayFunc: (() -> Bool)?

    var image: NSImage?
    var title: String?
    var body: String?
    var button1Title: String?
    var button2Title: String?
    var button3Title: String?
    var hideDismiss: Bool = false
    var labels: [String] = []

    var onButton1Func: ((_ viewController: NSViewController, _ completion: @escaping (() -> Void)) -> Void)?
    var onButton2Func: ((_ viewController: NSViewController, _ completion: @escaping (() -> Void)) -> Void)?

    var shouldDisplay: Bool {
        if let shouldDisplayFunc {
            return shouldDisplayFunc()
        } else {
            return true
        }
    }

    var isAppModal: Bool = false

    init(image: NSImage, title: String, body: String,
         button1Title: String?,
         button2Title: String? = nil,
         button3Title: String? = nil,
         hideDismiss: Bool = false,
         labels: [String] = [],
         shouldDisplay: (() -> Bool)? = nil,
         onButton1: ((_ viewController: NSViewController, _ completion: @escaping (() -> Void)) -> Void)? = nil,
         onButton2: ((_ viewController: NSViewController, _ completion: @escaping (() -> Void)) -> Void)? = nil)
    {
        self.image = image
        self.title = title
        self.body = body
        self.button1Title = button1Title
        self.button2Title = button2Title
        self.button3Title = button3Title
        self.hideDismiss = hideDismiss
        self.labels = labels

        shouldDisplayFunc = shouldDisplay
        onButton1Func = onButton1
        onButton2Func = onButton2
    }

    func instantiateViewController(completion: @escaping (() -> Void)) -> NSViewController {
        let ret = GenericOnboardingVC.fromStoryboard(module: self)

        ret.completion = completion

        return ret
    }
}

class GenericOnboardingVC: NSViewController {
    @IBOutlet var body: NSTextField!
    @IBOutlet var onboardingTitle: NSTextField!
    @IBOutlet var image: NSImageView!
    @IBOutlet var button1: NSButton!
    @IBOutlet var button2: NSButton!
    @IBOutlet var button3: NSButton!
    @IBOutlet var buttonDismiss: ClickableTextField!

    @IBOutlet var stackViewLabels: NSStackView!
    @IBOutlet var label1: NSTextField!
    @IBOutlet var label2: NSTextField!
    @IBOutlet var label3: NSTextField!
    @IBOutlet var label4: NSTextField!
    @IBOutlet var label5: NSTextField!

    var completion: (() -> Void)!

    var module: GenericOnboardingModule!

    class func fromStoryboard(module: GenericOnboardingModule) -> Self {
        let storyboard = NSStoryboard(name: "GenericOnboardingViewController", bundle: nil)

        let initial = storyboard.instantiateInitialController() as! Self

        initial.module = module

        return initial
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        if let title = module.title {
            view.window?.title = title
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if let icon = module.image {
            image.image = icon
        }

        if let title = module.title {
            onboardingTitle.stringValue = title

        }

        if let bodyText = module.body {
            body.stringValue = bodyText
        }

        if module.labels.isEmpty {
            stackViewLabels.isHidden = true
        } else {
            stackViewLabels.isHidden = false

            label1.isHidden = module.labels.count <= 0
            label2.isHidden = module.labels.count <= 1
            label3.isHidden = module.labels.count <= 2
            label4.isHidden = module.labels.count <= 3
            label5.isHidden = module.labels.count <= 4

            if module.labels.count > 0 {
                label1.stringValue = module.labels[0]
            }
            if module.labels.count > 1 {
                label2.stringValue = module.labels[1]
            }
            if module.labels.count > 2 {
                label3.stringValue = module.labels[2]
            }
            if module.labels.count > 3 {
                label4.stringValue = module.labels[3]
            }
            if module.labels.count > 4 {
                label5.stringValue = module.labels[4]
            }
        }

        if let button1Title = module.button1Title {
            button1.title = button1Title
        } else {
            button1.isHidden = true
        }

        if let button2Title = module.button2Title {
            button2.title = button2Title
        } else {
            button2.isHidden = true
        }
        if let button3Title = module.button3Title {
            button3.title = button3Title
        } else {
            button3.isHidden = true
        }

        if module.hideDismiss {
            buttonDismiss.isHidden = true
        }

        buttonDismiss.onClick = { [weak self] in
            self?.onDismiss()
        }
    }

    @IBAction func onButton1(_: Any) {
        if let button1Func = module.onButton1Func {
            button1Func(self, completion)
        } else {
            swlog("🔴 No Button1 Func Set!")
        }
    }

    @IBAction func onButton2(_: Any) {
        if let button2Func = module.onButton2Func {
            button2Func(self, completion)
        } else {
            swlog("🔴 No Button2 Func Set!")
        }
    }

    @IBAction func onButton3(_: Any) {}

    func onDismiss() {
        view.window?.close()
    }
}
