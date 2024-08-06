//
//  SwiftUIViewFactory.swift
//  MacBox
//
//  Created by Strongbox on 04/07/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Foundation
import SwiftUI









class SwiftUIViewFactory: NSObject {
    @objc static func showKeyFileGeneratorScreen(keyFile: KeyFile,
                                                 onPrint: @escaping (() -> Void),
                                                 onSave: @escaping (() -> Bool))
    {
        let window = EscapableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 800),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        let view = GenerateKeyFileScreen(keyFile: keyFile, onPrint: onPrint, onSave: onSave) {
            window.orderOut(nil)
        }

        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("new-key-file-autosave")
        window.title = NSLocalizedString("new_key_file", comment: "New Key File")
        window.contentView = NSHostingView(rootView: view)
        window.makeKeyAndOrderFront(nil)
    }

    @objc static func showKeyFileRecoveryScreen(_ onRecover: @escaping ((_ keyFile: KeyFile) -> Void)) {
        let window = EscapableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 800),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

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

                                            window.orderOut(nil)
                                        })

        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("recover-key-file-autosave")
        window.title = NSLocalizedString("recover_key_file_title", comment: "Recover Key File")
        window.contentView = NSHostingView(rootView: view)
        window.makeKeyAndOrderFront(nil)
    }

    @objc static func makeImportResultViewController(messages: [ImportMessage] = [], dismissHandler: @escaping ((_ cancel: Bool) -> Void)) -> NSViewController {
        let hostingController = NSHostingController(rootView: ImportResultView(dismiss: dismissHandler, messages: messages))

        hostingController.preferredContentSize = NSSize(width: 400, height: 400)
        if #available(macOS 13.0, *) {
            hostingController.sizingOptions = .preferredContentSize
        }

        return hostingController
    }

    @objc static func makeWiFiSyncPassCodeEntryViewController(_ server: WiFiSyncServerConfig, onDone: @escaping ((_ server: WiFiSyncServerConfig?, _ pinCode: String?) -> Void)) -> NSViewController {
        let hostingController = NSHostingController(rootView: MacWiFiSyncPasscodeEntryView(server: server, onDone: onDone))

        hostingController.preferredContentSize = NSSize(width: 350, height: 400)
        if #available(macOS 13.0, *) {
            hostingController.sizingOptions = .preferredContentSize
        }

        return hostingController
    }

    @objc static func makeSaleOfferViewController(sale: Sale,
                                                  existingSubscriber: Bool,
                                                  redeemHandler: @escaping (() -> Void),
                                                  onLifetimeHandler: @escaping (() -> Void),
                                                  dismissHandler: @escaping (() -> Void)) -> NSViewController
    {
        let hostingController = NSHostingController(rootView: SaleOfferView(dismiss: dismissHandler,
                                                                            onLifetime: onLifetimeHandler,
                                                                            redeem: redeemHandler,
                                                                            sale: sale,
                                                                            existingSubscriber: existingSubscriber))

        hostingController.preferredContentSize = NSSize(width: 400, height: 400)
        if #available(macOS 13.0, *) {
            hostingController.sizingOptions = .preferredContentSize
        }

        hostingController.title = NSLocalizedString("sale_view_regular_title", comment: "Sale Now On")

        return hostingController
    }

    @objc static func makeStorageSelector(createMode: Bool,
                                          isImporting: Bool,
                                          isPro: Bool,
                                          cloudKitUnavailableReason: String?,
                                          initialSelection: StorageProvider,
                                          completion: @escaping ((_ userCancelled: Bool, _ selected: StorageProvider, _ selectedWiFiSyncDevice: WiFiSyncServerConfig?) -> Void)) -> NSViewController
    {
        NSHostingController(rootView: StorageSelectorView(createMode: createMode, isImporting: isImporting, isPro: isPro, cloudKitUnavailableReason: cloudKitUnavailableReason, initialSelection: initialSelection, completion: completion))
    }
}
