//
//  SwiftUIAutoFillHelper.swift
//  MacBox
//
//  Created by Strongbox on 28/08/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import AuthenticationServices
import CryptoKit
import Foundation
import SwiftCBOR
import SwiftUI

enum SwiftUIAutoFillHelperError: Error {
    case Assertion(detail: String)
    case Registration(detail: String)
}

@available(iOS 17.0, macOS 13.0, *)
@objc
class SwiftUIAutoFillHelper: NSObject {
    @objc
    static let shared: SwiftUIAutoFillHelper = .init()

    override private init() {}

    @objc
    func createAndSaveNewEntry(model: Model,
                               initialTitle: String?,
                               initialUrl: String?,
                               parentViewController: VIEW_CONTROLLER_PTR,
                               completion: @escaping ((_ cancel: Bool, _ node: Node?, _ error: Error?) -> Void)) throws
    {
        do {
            try showCreateNewDialogAndSave(model: model,
                                           initialTitle: initialTitle,
                                           initialUrl: initialUrl,
                                           parentViewController: parentViewController)
            { cancelled, node, error in
                if let error {
                    swlog("🔴 Could not save new entry to database...")
                    completion(false, node, error)
                } else if cancelled {
                    completion(true, node, nil)
                } else {
                    completion(false, node, nil)
                }
            }
        } catch {
            completion(false, nil, error)
        }
    }

    func showCreateNewDialogAndSave(model: Model,
                                    initialTitle: String?,
                                    initialUrl: String?,
                                    parentViewController: VIEW_CONTROLLER_PTR,
                                    completion: @escaping ((_ cancelled: Bool, _ node: Node?, _ error: Error?) -> Void)) throws
    {
        #if os(iOS)
            
            return
        #else

            let sortedGroups = AddOrCreateHelper.getSortedGroups(model)
            var sortedPaths = sortedGroups.map { AddOrCreateHelper.getGroupPathDisplayString($0, model.database) }
            let rootPath = AddOrCreateHelper.getGroupPathDisplayString(model.database.effectiveRootGroup, model.database, true)
            sortedPaths.insert(rootPath, at: 0)

            let template = NewEntryDefaultsHelper.getDefaultNewEntryNode(model.database, parentGroup: model.database.effectiveRootGroup)

            let createNewDialog = AutoFillCreateNewEntryDialog(title: initialTitle ?? template.title,
                                                               url: initialUrl ?? template.fields.url,
                                                               username: template.fields.username,
                                                               password: template.fields.password,
                                                               groups: sortedPaths,
                                                               selectedGroupIdx: 0)
            {
                [weak self] cancel, title, username, password, url, selectedGroupIdx in
                self?.handleCreateNewDialogResponse(model, sortedGroups, cancel, title, username, password, url, selectedGroupIdx, completion)
            }

            let hostingController = NSHostingController(rootView: createNewDialog)

            hostingController.preferredContentSize = NSSize(width: 400, height: 400)
            hostingController.sizingOptions = .preferredContentSize

            parentViewController.presentAsSheet(hostingController)
        #endif
    }

    func handleCreateNewDialogResponse(_ model: Model, _ sortedGroups: [Node], _ cancel: Bool, _ title: String, _ username: String, _ password: String, _ url: String, _ selectedGroupIdx: Int?, _ completion: @escaping ((_ cancelled: Bool, _ node: Node?, _ error: Error?) -> Void)) {
        swlog("🟢 handleCreateNewDialogResponse")

        if cancel {
            completion(true, nil, nil)
        } else {
            guard let selectedGroupIdx, let group = selectedGroupIdx == 0 ? model.database.effectiveRootGroup : sortedGroups[safe: selectedGroupIdx - 1] else {
                completion(false, nil, Utils.createNSError("Could not get group or title!", errorCode: 123))
                return
            }

            do {
                try saveNewEntry(model, title, username, password, url, group) { cancelled, node, error in
                    completion(cancelled, node, error)
                }
            } catch {
                completion(false, nil, error)
            }
        }
    }

    func saveNewEntry(_ model: Model,
                      _ title: String,
                      _ username: String,
                      _ password: String,
                      _ url: String,
                      _ group: Node,
                      _ completion: @escaping (_ cancelled: Bool, _ node: Node?, _ error: Error?) -> Void) throws
    {
        #if os(iOS)
            
            return
        #else

            let node = NewEntryDefaultsHelper.getDefaultNewEntryNode(model.database, parentGroup: group)
            node.setTitle(title, keePassGroupTitleRules: model.originalFormat != .passwordSafe)

            node.fields.username = username
            node.fields.password = password
            node.fields.url = url

            if !model.addChildren([node], destination: group) {
                throw SwiftUIAutoFillHelperError.Registration(detail: "🔴 Could not add new entry to database!")
            }

            save(model, node) { cancelled, error in
                completion(cancelled, node, error)
            }
        #endif
    }

    

    @objc
    @available(macOS 14.0, *)
    func registerAndSaveNewPasskey(_ registrationRequest: ASCredentialRequest,
                                   model: Model,
                                   parentViewController: VIEW_CONTROLLER_PTR,
                                   completion: @escaping ((_ cancel: Bool, _ credential: ASPasskeyRegistrationCredential?, _ error: Error?) -> Void)) throws
    {
        guard let request = registrationRequest as? ASPasskeyCredentialRequest else {
            throw SwiftUIAutoFillHelperError.Registration(detail: "🔴 This isn't a ASPasskeyCredentialRequest! Bailing")
        }

        

        guard request.supportedAlgorithms.contains(.ES256) else { 
            throw SwiftUIAutoFillHelperError.Registration(detail: "🔴 ES256 is not in the supported algorithms list!")
        }

        let identity = request.credentialIdentity as! ASPasskeyCredentialIdentity

        guard let passkey = Passkey(relyingPartyId: identity.relyingPartyIdentifier, username: identity.userName, userHandleData: identity.userHandle) else {
            throw SwiftUIAutoFillHelperError.Registration(detail: "🔴 Could not get new Passkey")
        }

        
        guard let attestationObjectData = try CBOREncodingHelper.getAttestationObjectNone(passkey) else {
            
            throw SwiftUIAutoFillHelperError.Registration(detail: "🔴 Could not get attestation Object")
        }

        

        

        

        do {
            try savePasskeyToDatabase(passkey, model, parentViewController) { cancelled, error in
                if let error {
                    swlog("🔴 Could not save Passkey to database...")
                    completion(false, nil, error)
                } else if cancelled {
                    completion(true, nil, nil)
                } else {
                    let response = ASPasskeyRegistrationCredential(
                        relyingParty: passkey.relyingPartyId, 
                        clientDataHash: request.clientDataHash, 
                        credentialID: passkey.credentialIdData, 
                        attestationObject: attestationObjectData
                    )

                    completion(false, response, nil)
                }
            }
        } catch {
            completion(false, nil, error)
        }
    }

    @available(macOS 14.0, *)
    func savePasskeyToDatabase(_ passkey: Passkey,
                               _ model: Model,
                               _ parentViewController: VIEW_CONTROLLER_PTR,
                               _ completion: @escaping ((_ cancelled: Bool, _ error: Error?) -> Void)) throws
    {
        let sortedGroups = AddOrCreateHelper.getSortedGroups(model)
        var sortedPaths = sortedGroups.map { AddOrCreateHelper.getGroupPathDisplayString($0, model.database) }
        let rootPath = AddOrCreateHelper.getGroupPathDisplayString(model.database.effectiveRootGroup, model.database, true)
        sortedPaths.insert(rootPath, at: 0)

        let entries = NSMutableArray(array: model.allSearchableNoneExpiredEntries)
        let sorted = model.filterAndSort(forBrowse: entries, includeGroups: false)

        #if os(iOS)
            let wizard = AddOrCreateWizard(mode: .passkey,
                                           title: passkey.relyingPartyId,
                                           groups: sortedPaths,
                                           entries: sorted,
                                           selectedGroupIdx: 0,
                                           model: model)
            { [weak self] cancel, createNew, title, selectedGroupIdx, selectedEntry in
                self?.handlePasskeyWizardResponse(passkey, model, sortedGroups, cancel, createNew, title, selectedGroupIdx, selectedEntry, completion)
            }
            parentViewController.present(UIHostingController(rootView: wizard), animated: true)
        #else
            let wizard = WizardAddToOrCreateNewView(mode: .passkey, entries: sorted, model: model, title: passkey.relyingPartyId, groups: sortedPaths) { [weak self] cancel, createNew, title, selectedGroupIdx, selectedEntry in
                Utils.dismissViewControllerCorrectly(parentViewController.presentedViewControllers?.last)

                self?.handlePasskeyWizardResponse(passkey, model, sortedGroups, cancel, createNew, title, selectedGroupIdx, selectedEntry, completion)
            }

            let hostingController = NSHostingController(rootView: wizard)




            parentViewController.presentAsSheet(hostingController)
        #endif
    }

    func handlePasskeyWizardResponse(_ passkey: Passkey, _ model: Model, _ sortedGroups: [Node], _ cancel: Bool, _ createNew: Bool, _ title: String?, _ selectedGroupIdx: Int?, _ selectedEntry: UUID?, _ completion: @escaping ((_ cancelled: Bool, _ error: Error?) -> Void)) {
        

        if cancel {
            completion(true, nil)
        } else if createNew {
            guard let title, let selectedGroupIdx, let group = selectedGroupIdx == 0 ? model.database.effectiveRootGroup : sortedGroups[safe: selectedGroupIdx - 1] else {
                completion(false, Utils.createNSError("Could not get group or title!", errorCode: 123))
                return
            }

            do {
                try savePasskeyToNewEntry(passkey, model, title, group) { cancelled, error in
                    completion(cancelled, error)
                }
            } catch {
                completion(false, error)
            }
        } else {
            guard let selectedEntry, let entry = model.getItemBy(selectedEntry) else {
                completion(false, Utils.createNSError("Could not get selected entry!", errorCode: 123))
                return
            }

            savePasskeyToExistingEntry(passkey, model, entry) { cancelled, error in
                completion(cancelled, error)
            }
        }
    }

    func savePasskeyToExistingEntry(_ passkey: Passkey,
                                    _ model: Model,
                                    _ entry: Node,
                                    _ completion: @escaping (_ cancelled: Bool, _ error: Error?) -> Void)
    {
        entry.passkey = passkey

        if entry.fields.username.count == 0 {
            entry.fields.username = passkey.username
        }

        if entry.fields.url.count == 0 {
            entry.fields.url = String(format: "https:
        }

        entry.touch(true)

        save(model, entry, completion)
    }

    func savePasskeyToNewEntry(_ passkey: Passkey,
                               _ model: Model,
                               _ title: String,
                               _ group: Node,
                               _ completion: @escaping (_ cancelled: Bool, _ error: Error?) -> Void) throws
    {
        let node = Node(asRecord: title, parent: group)
        node.passkey = passkey
        node.icon = NodeIcon.withPreset(58) 

        node.fields.url = String(format: "https:
        node.fields.username = passkey.username

        if !model.addChildren([node], destination: group) {
            throw SwiftUIAutoFillHelperError.Registration(detail: "🔴 Could not add Passkey to database!")
        }

        save(model, node, completion)
    }

    func save(_ model: Model, _ node: Node, _ completion: @escaping (_ cancelled: Bool, _ error: Error?) -> Void) {
        let prefs = CrossPlatformDependencies.defaults().applicationPreferences

        prefs.autoFillWroteCleanly = false

        model.asyncUpdate { result in
            swlog("🐞 AutoFill Async Update Done: [%@]", String(describing: result))
            prefs.autoFillWroteCleanly = true

            

            if result.userCancelled {
                completion(true, nil)
            } else if let error = result.error {
                completion(false, error)
            } else {
                

                AutoFillManager.sharedInstance().refreshQuickType(afterAutoFillAddition: node, database: model)

                completion(false, nil)
            }
        }
    }

    @available(macOS 14.0, iOS 17.0, *)
    @objc
    func getAutoFillAssertion(request: ASPasskeyCredentialRequest, passkey: Passkey) throws -> ASPasskeyAssertionCredential {
        swlog("🟢 getAutoFillAssertion = [%@]", request)

        guard let authenticatorData = passkey.getAuthenticatorData(includeAttestedCredentialData: false) else {
            throw SwiftUIAutoFillHelperError.Assertion(detail: "🔴 Could not generate Authenticator Data")
        }

        let signatureDer = try getAutoFillAssertionSignatureDer(clientDataHash: request.clientDataHash, authenticatorData: authenticatorData, passkey: passkey)

        return ASPasskeyAssertionCredential(userHandle: passkey.userHandleData,
                                            relyingParty: passkey.relyingPartyId,
                                            signature: signatureDer,
                                            clientDataHash: request.clientDataHash,
                                            authenticatorData: authenticatorData,
                                            credentialID: passkey.credentialIdData)
    }

    @available(macOS 14.0, iOS 17.0, *)
    @objc
    public func getAutoFillAssertionSignatureDer(clientDataHash: Data, authenticatorData: Data, passkey: Passkey) throws -> Data {
        swlog("🟢 getAutoFillAssertionSignatureDer = [%@]", clientDataHash.base64EncodedString())

        var concatenation = Data(authenticatorData)
        concatenation.append(clientDataHash)

        guard let signature = passkey.signChallenge(concatenation) else {
            throw SwiftUIAutoFillHelperError.Assertion(detail: "🔴 Passkey: Could not signChallenge")
        }

        return signature.derRepresentation
    }
}
