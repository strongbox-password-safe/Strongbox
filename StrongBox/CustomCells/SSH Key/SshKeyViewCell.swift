//
//  SshKeyViewCell.swift
//  Strongbox
//
//  Created by Strongbox on 30/05/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Foundation

class SshKeyViewCell: UITableViewCell {
    @IBOutlet var labelPassphraseProtected: UILabel!
    @IBOutlet var labelFilename: UILabel!
    @IBOutlet var labelFingerprint: UILabel!
    @IBOutlet var labelPublicKey: UILabel!
    @IBOutlet var labelSshAgentEnabled: UILabel!
    @IBOutlet var labelAlgo: UILabel!
    @IBOutlet var stackPassphrase: UIStackView!
    @IBOutlet var imageViewPassphrase: UIImageView!
    @IBOutlet var imageViewAgentStatus: UIImageView!

    @IBOutlet var stackFingerprint: UIStackView!
    @IBOutlet var stackPrivateKey: UIStackView!
    @IBOutlet var stackPublicKey: UIStackView!

    @IBOutlet var stackSshStatus: UIStackView!
    @IBOutlet var buttonSharePublic: UIButton!
    @IBOutlet var buttonSharePrivate: UIButton!

    @IBOutlet var labelSshKey: UILabel!

    private var key: KeeAgentSshKeyViewModel? = nil
    private var password: String? = nil
    private var viewController: UIViewController? = nil
    var editMode: Bool = false

    var onCopyPub: (() -> Void)? = nil
    var onCopyPrivate: (() -> Void)? = nil
    var onCopyFinger: (() -> Void)? = nil

    @objc public func setContent(_ key: KeeAgentSshKeyViewModel,
                                 password: String,
                                 viewController: UIViewController,
                                 editMode: Bool,
                                 onCopyPub: (() -> Void)? = nil,
                                 onCopyPrivate: (() -> Void)? = nil,
                                 onCopyFinger: (() -> Void)? = nil)
    {
        accessoryType = .none
        editingAccessoryType = .none

        self.key = key
        self.password = password
        self.viewController = viewController
        self.onCopyPub = onCopyPub
        self.onCopyPrivate = onCopyPrivate
        self.onCopyFinger = onCopyFinger
        self.editMode = editMode

        bindUI()
    }

    func bindUI() {
        guard let key else {
            swlog("Could not convert field into KeeAgentSshKeyViewModel")

            labelFilename.text = NSLocalizedString("generic_error", comment: "Error")
            labelFingerprint.text = NSLocalizedString("generic_error", comment: "Error")
            labelPublicKey.text = NSLocalizedString("generic_error", comment: "Error")
            labelAlgo.text = NSLocalizedString("generic_error", comment: "Error")
            labelSshAgentEnabled.text = NSLocalizedString("generic_error", comment: "Error")

            return
        }

        labelFilename.text = key.filename
        labelFingerprint.text = key.openSshKey.fingerprint
        labelPublicKey.text = key.openSshKey.publicKey

        stackPassphrase.isHidden = !key.openSshKey.isPassphraseProtected

        if key.openSshKey.isPassphraseProtected {
            var valid = false
            if let password, password.count > 0 {
                valid = key.openSshKey.validatePassphrase(password)
            }

            labelPassphraseProtected.text = valid ? NSLocalizedString("ssh_agent_passphrase_protected", comment: "Passphrase Protected") : NSLocalizedString("ssh_agent_passphrase_protected_incorrect", comment: "Passphrase Protected (Entry Password Incorrect)")

            labelPassphraseProtected.textColor = valid ? .label : .systemOrange
            labelPassphraseProtected.font = valid ? FontManager.sharedInstance().regularFont : FontManager.sharedInstance().caption2Font

            imageViewPassphrase.tintColor = valid ? .label : .systemOrange
        }

        labelAlgo.text = key.openSshKey.type

        labelSshAgentEnabled.text = key.enabled ? NSLocalizedString("ssh_agent_key_enabled_for_agent", comment: "Enabled for SSH Agent") : NSLocalizedString("ssh_agent_disabled_for_agent", comment: "Disabled for SSH Agent")

        imageViewAgentStatus.tintColor = key.enabled ? .systemGreen : .secondaryLabel

        stackPublicKey.isHidden = editMode
        stackPrivateKey.isHidden = editMode
        stackFingerprint.isHidden = editMode
        stackSshStatus.isHidden = editMode
    }

    @IBAction func onCopyPrivate(_: Any) {
        onCopyPrivate?()
    }

    @IBAction func onCopyPublic(_: Any) {
        onCopyPub?()
    }

    @IBAction func onCopyFingerprint(_: Any) {
        onCopyFinger?()
    }

    @IBAction func onExportPrivate(_: Any) {
        guard let key, let viewController else {
            swlog("Could not convert field into KeeAgentSshKeyViewModel")
            return
        }

        guard let alert = Alerts(title: NSLocalizedString("generic_export", comment: "Export"),
                                 message: NSLocalizedString("ssh_agent_enter_passphrase_for_export", comment: "Enter a passphrase to protect the exported key file"))
        else {
            return
        }

        alert.okCancel(withPasswordAllowEmpty: viewController) { [weak self] passphrase, response in
            guard response, let passphrase, let password = self?.password, let self else {
                return
            }

            let foo = NSTemporaryDirectory() as NSString
            let path = foo.appendingPathComponent(key.filename)
            let url = URL(fileURLWithPath: path)

            guard let data = key.openSshKey.exportFileBlob(password, exportPassphrase: passphrase) else {
                Alerts.info(viewController,
                            title: NSLocalizedString("export_vc_error_exporting", comment: "Error Exporting"),
                            message: NSLocalizedString("export_vc_error_exporting", comment: "Error Exporting"))
                return
            }

            do {
                try data.write(to: url)
            } catch {
                Alerts.error(viewController, error: error)
                return
            }

            self.export(viewController, url: url, popoverView: self.buttonSharePrivate)
        }
    }

    @IBAction func onExportPublic(_: Any) {
        guard let key, let viewController else {
            swlog("Could not convert field into KeeAgentSshKeyViewModel")
            return
        }

        let foo = NSTemporaryDirectory() as NSString
        let filename = key.filename.appending(".pub")
        let path = foo.appendingPathComponent(filename)
        let url = URL(fileURLWithPath: path)

        guard let data = key.openSshKey.publicKey.data(using: .utf8) else {
            Alerts.info(viewController,
                        title: NSLocalizedString("export_vc_error_exporting", comment: "Error Exporting"),
                        message: NSLocalizedString("export_vc_error_exporting", comment: "Error Exporting"))
            return
        }

        do {
            try data.write(to: url)
        } catch {
            Alerts.error(viewController, error: error)
            return
        }

        export(viewController, url: url, popoverView: buttonSharePublic)
    }

    func export(_ viewController: UIViewController, url: URL, popoverView: UIView) {
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        

        activityViewController.popoverPresentationController?.sourceView = popoverView
        activityViewController.popoverPresentationController?.sourceRect = popoverView.bounds
        activityViewController.popoverPresentationController?.permittedArrowDirections = .any

        activityViewController.completionWithItemsHandler = { _, _, _, _ in
            
            try? FileManager.default.removeItem(at: url)
        }

        viewController.present(activityViewController, animated: true)
    }
}
