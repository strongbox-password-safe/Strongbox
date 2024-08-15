//
//  SwiftUIViewFactory.swift
//  Strongbox
//
//  Created by Strongbox on 05/07/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Foundation
import SwiftUI

class SwiftUIViewFactory: NSObject {
    @objc static func makeImportResultViewController(messages: [ImportMessage] = [],
                                                     dismissHandler: @escaping ((_ cancel: Bool) -> Void)) -> UIViewController
    {
        let hostingController = UIHostingController(rootView: ImportResultView(dismiss: dismissHandler, messages: messages))

        return hostingController
    }

    @objc static func makeSaleOfferViewController(sale: Sale,
                                                  existingSubscriber: Bool,
                                                  redeemHandler: @escaping (() -> Void),
                                                  onLifetimeHandler: @escaping (() -> Void),
                                                  dismissHandler: @escaping (() -> Void)) -> UIViewController
    {
        let hostingController = UIHostingController(rootView: SaleOfferView(dismiss: dismissHandler, onLifetime: onLifetimeHandler, redeem: redeemHandler, sale: sale, existingSubscriber: existingSubscriber))

        return hostingController
    }

    @objc static func makeWiFiSyncPasscodeViewController(_ server: WiFiSyncServerConfig, onDone: @escaping ((_ server: WiFiSyncServerConfig?, _ pinCode: String?) -> Void)) -> UIViewController {
        let hostingController = UIHostingController(rootView: PasscodeEntryView(server: server, onDone: onDone))

        return hostingController
    }

    @objc static func showKeyFileGeneratorScreen(keyFile: KeyFile,
                                                 onPrint: @escaping (() -> Void),
                                                 onSave: @escaping (() -> Bool),
                                                 onDismiss: @escaping (() -> Void)) -> UIViewController
    {
        let view = GenerateKeyFileScreen(keyFile: keyFile, onPrint: onPrint, onSave: onSave) {
            onDismiss()
        }

        let hostingController = UIHostingController(rootView: view)

        return hostingController
    }

    @objc static func showKeyFileRecoveryScreen(onRecover: @escaping ((_ keyFile: KeyFile) -> Void),
                                                onDismiss: @escaping (() -> Void)) -> UIViewController
    {
        let view = RecoverKeyFileScreen(verifyHash: { codes, hash in
                                            guard let keyFile = KeyFile.fromHexCodes(codes) else {
                                                return false
                                            }

                                            return keyFile.hashString.uppercased() == hash.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                                        },
                                        validateCodes: { codes in
                                            KeyFile.fromHexCodes(codes) != nil
                                        },
                                        onRecover: { codes in
                                            guard let keyFile = KeyFile.fromHexCodes(codes) else {
                                                swlog("🔴 ERROR: Invalid Hex Codes for Key File, should never happen!")
                                                return
                                            }

                                            onRecover(keyFile)
                                            onDismiss()
                                        }) {
            onDismiss()
        }

        let hostingController = UIHostingController(rootView: view)

        return hostingController
    }

    @objc static func getLargeTextDisplayView(text: String, font: UIFont, colorMapper: @escaping ((_ character: String) -> UIColor), onTapped: @escaping (() -> Void)) -> UIViewController {
        let view = LargeTextDisplayView(text: text, font: Font(font), colorMapper: { char in
            Color(colorMapper(char))
        }) {
            onTapped()
        }

        let hostingController = UIHostingController(rootView: view.ignoresSafeArea())

        return hostingController
    }

    @objc static func getTagsEditorView(existingTags: Set<String>,
                                        allTags: Set<String>,
                                        completion: @escaping ((_ cancelled: Bool, _ selectedTags: Set<String>?) -> Void)) -> UIViewController
    {
        let view = TagsEditorView(currentItemTags: existingTags, allTags: allTags, completion: completion)

        let hostingController = UIHostingController(rootView: view)

        return hostingController
    }

    #if !IS_APP_EXTENSION && !NO_NETWORKING
        @objc static func getOneDriveRootNavigatorView(existing: Bool, completion: @escaping ((_ cancelled: Bool, _ selectedMode: OneDriveNavigationContextMode) -> Void)) -> UIViewController {
            let view = OneDriveRootNavigator(selectExisting: existing, appIsPro: AppPreferences.sharedInstance().isPro, completion: completion)

            let hostingController = UIHostingController(rootView: view)

            return hostingController
        }
    #endif

    #if !IS_APP_EXTENSION
        static func getDatabaseHomeView(model: DatabaseHomeViewModel) -> UIViewController {
            let view = DatabaseHomeView(model: model)

            let hostingController = UIHostingController(rootView: view)

            return hostingController
        }

        static func getAuditIssuesView(model: DatabaseHomeViewModel) -> UIViewController {
            UIHostingController(rootView: AuditNavigationView(model: model))
        }

        @objc
        static func getHardwareKeySettingsView(metadata: METADATA_PTR, onSettingsChanged: ((Bool, Int, Int, Bool) -> Void)?, completion: (() -> Void)? = nil) -> UIViewController {
            UIHostingController(
                rootView: HardwareKeySettingsView(
                    keyCachingEnabled: metadata.hardwareKeyCRCaching,
                    autoFillRefreshSuppressed: metadata.doNotRefreshChallengeInAF,
                    cacheChallengeDurationSecs: metadata.cacheChallengeDurationSecs,
                    challengeRefreshIntervalSecs: metadata.challengeRefreshIntervalSecs,
                    onSettingsChanged: onSettingsChanged,
                    completion: completion
                ))
        }

    #endif
}
