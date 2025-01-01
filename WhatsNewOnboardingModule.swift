//
//  WhatsNewOnboardingModule.swift
//
//
//  Created by Strongbox on 22/12/2024.
//

import Foundation

@objc
class WhatsNewMessage: NSObject, Identifiable {
    var id: Int { sequenceNumber }

    var sequenceNumber: Int
    var version: String
    var markdownBody: String

    init(sequenceNumber: Int, version: String, markdownBody: String) {
        self.sequenceNumber = sequenceNumber
        self.version = version
        self.markdownBody = markdownBody
    }
}

@objc
public class WhatsNewOnboardingModule: NSObject, OnboardingModule {
    static let markdownBody_1_60_30 =
        """
        #### Apple Watch App
        - You can now sync individual entries from your databases to your Apple Watch. 
        - Install the Strongbox App on your watch to get started.

        #### 2FA Code Improvements 
        - We've improved 2FA Code display and animation. We hope you'll like it! 

        """

    static let Messages: [WhatsNewMessage] = [
        WhatsNewMessage(sequenceNumber: 8, version: "1.60.30", markdownBody: markdownBody_1_60_30),
    ]

    var lastDisplayedWhatsNewMessage: Int {
        get {
            AppPreferences.sharedInstance().lastDisplayedWhatsNewMessage
        }
        set {
            AppPreferences.sharedInstance().lastDisplayedWhatsNewMessage = newValue
        }
    }

    var latestMessageSequenceNumber: Int {
        Self.Messages.last?.sequenceNumber ?? -1
    }

    public required init(model _: Model?) {}

    public func shouldDisplay() -> Bool {
        if AppPreferences.sharedInstance().launchCount < 3 { 
            lastDisplayedWhatsNewMessage = latestMessageSequenceNumber
            return false
        }

        return latestMessageSequenceNumber > lastDisplayedWhatsNewMessage
    }

    public func instantiateViewController(_ onDone: @escaping OnboardingModuleDoneBlock) -> VIEW_CONTROLLER_PTR? {
        let updates = Self.Messages.filter { message in
            message.sequenceNumber > lastDisplayedWhatsNewMessage
        }

        let vcc = SwiftUIViewFactory.makeWhatsNewViewController(updates.reversed()) {
            onDone(false, false)
        }

        lastDisplayedWhatsNewMessage = latestMessageSequenceNumber

        return vcc
    }
}
