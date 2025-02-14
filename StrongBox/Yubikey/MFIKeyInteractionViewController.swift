// Copyright 2018-2019 Yubico AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.



import UIKit

enum MFIKeyInteractionViewControllerState {
    case insertKey
    case touchKey
    case processing
}

class MFIKeyInteractionViewController: RootViewController, MFIKeyActionSheetViewDelegate {
    private var mfiKeyActionSheetView: MFIKeyActionSheetView?

    

    override func viewDidLoad() {
        super.viewDidLoad()

        let selector = #selector(applicationWillResignActive)
        let notificationName = UIApplication.willResignActiveNotification
        NotificationCenter.default.addObserver(self, selector: selector, name: notificationName, object: nil)
    }

    deinit {
        let notificationName = UIApplication.willResignActiveNotification
        NotificationCenter.default.removeObserver(self, name: notificationName, object: nil)

        
        observeAccessorySessionStateUpdates = false
        observeFIDO2ServiceStateUpdates = false
    }

    

    @objc func applicationWillResignActive() {
        dismissMFIKeyActionSheet()
    }

    

    private func set(state: MFIKeyInteractionViewControllerState, message: String) {
        guard let actionSheet = mfiKeyActionSheetView else {
            return
        }
        switch state {
        case .insertKey:
            actionSheet.animateInsertKey(message: message)
        case .touchKey:
            actionSheet.animateTouchKey(message: message)
        case .processing:
            actionSheet.animateProcessing(message: message)
        }
    }

    

    override func viewWillTransition(to _: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.updateActionSheetOrientation()
        }, completion: nil)
    }

    private func updateActionSheetOrientation() {
        let interfaceOrientation = UIApplication.shared.statusBarOrientation
        mfiKeyActionSheetView?.updateInterfaceOrientation(orientation: interfaceOrientation)
    }

    

    func presentMFIKeyActionSheet(state: MFIKeyInteractionViewControllerState, message: String, completion: @escaping () -> Void = {}) {
        dispatchMain { [weak self] in
            guard let self else {
                return
            }
            guard self.mfiKeyActionSheetView == nil else {
                self.set(state: state, message: message)
                completion()
                return
            }



            if let actionSheet = self.mfiKeyActionSheetView, let parentView = UIApplication.shared.keyWindow {
                actionSheet.delegate = self
                actionSheet.frame = parentView.bounds
                parentView.addSubview(actionSheet)

                actionSheet.present(animated: true, completion: completion)
                self.set(state: state, message: message)
            } else {
                fatalError()
            }

            self.updateActionSheetOrientation()
        }
    }

    func dismissMFIKeyActionSheet(delayed: Bool = true, completion: @escaping () -> Void = {}) {
        dispatchMain { [weak self] in
            guard let self else {
                return
            }
            guard let actionSheet = self.mfiKeyActionSheetView else {
                completion()
                return
            }
            actionSheet.dismiss(animated: true, delayed: delayed) { [weak self] in
                guard let self else {
                    return
                }
                if let lightingActionSheet = self.mfiKeyActionSheetView {
                    lightingActionSheet.removeFromSuperview()
                    self.mfiKeyActionSheetView = nil
                }
                completion()
            }
        }
    }

    func dismissMFIKeyActionSheetAndPresent(message: String) {
        dismissMFIKeyActionSheet { [weak self] in
            self?.present(message: message)
        }
    }

    

    func mfiKeyActionSheetDidDismiss() {
        dismissMFIKeyActionSheet(delayed: false, completion: {})
    }

    

    private var isObservingAccessorySessionStateUpdates = false
    private var accessorySessionStateObservation: NSKeyValueObservation?

    var observeAccessorySessionStateUpdates: Bool {
        get {
            isObservingAccessorySessionStateUpdates
        }
        set {
            guard newValue != isObservingAccessorySessionStateUpdates else {
                return
            }
            isObservingAccessorySessionStateUpdates = newValue

            if isObservingAccessorySessionStateUpdates {
                /*
                 let accessorySession = YubiKitManager.shared.accessorySession
                 accessorySessionStateObservation = accessorySession.observe(\.connectionState, changeHandler: { [weak self] session, change in
                     DispatchQueue.main.async {
                         self?.accessorySessionStateDidChange()
                     }
                 })
                 */
            } else {
                accessorySessionStateObservation = nil
            }
        }
    }

    private var isObservingFIDO2ServiceStateUpdates = false
    private var fido2ServiceStateObservation: NSKeyValueObservation?

    var observeFIDO2ServiceStateUpdates: Bool {
        get {
            isObservingFIDO2ServiceStateUpdates
        }
        set {















        }
    }

    func accessorySessionStateDidChange() {
        fatalError("Override the accessorySessionStateDidChange() to get Key Session state updates.")
    }

    func fido2ServiceStateDidChange() {
        fatalError("Override the fido2ServiceStateDidChange() to get FIDO2 Service state updates.")
    }
}
