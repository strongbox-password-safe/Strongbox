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
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit

class RootViewController: UIViewController {
    
    private var progressHud: ProgressHudView?

    // MARK: - Progress HUD
    
    func presentProgressHud(message: String) {
        dispatchMain { [weak self] in
            guard let self = self else {
                return
            }
            guard self.progressHud == nil else {
                self.progressHud!.messageLabel.text = message
                return
            }
            
            self.progressHud = Bundle.main.loadNibNamed("ProgressHudView", owner: nil, options: nil)?.first as? ProgressHudView
            self.progressHud!.messageLabel.text = message
            
            var targetController: UIViewController = self
            if self.navigationController != nil {
                targetController = self.navigationController!
            }
            if self.tabBarController != nil {
                targetController = self.tabBarController!
            }
            
            self.pinViewToEdges(self.progressHud!, on: targetController)
        }
    }
    
    func dismissProgressHud() {
        dispatchMain { [weak self] in
            guard let self = self else {
                return
            }
            guard self.progressHud != nil else {
                return
            }
            self.progressHud!.removeFromSuperview()
            self.progressHud = nil
        }
    }
            
    func dismissProgressHudAndPresent(message: String) {
        dismissProgressHud()
        present(message: message)
    }

    func dismissProgressHudAndPresent(error: Error) {
        dismissProgressHudAndPresent(message: error.localizedDescription)
    }
    
    // MARK: - Message Presenting

    func present(message: String) {
        dispatchMain { [weak self] in
            let alert = UIAlertController(title: "", message: message, preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
            self?.present(alert, animated: true, completion: nil)
        }
    }
    
    func present(error: Error) {
        dispatchMain { [weak self] in
            let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
            self?.present(alert, animated: true, completion: nil)
        }
    }
    
    // MARK: - Autolayout
    
    func pinViewToEdges(_ view: UIView, on viewController: UIViewController? = nil) {
        view.translatesAutoresizingMaskIntoConstraints = false
        let targetController = viewController ?? self
        
        targetController.view.addSubview(view)
        
        let left = NSLayoutConstraint(item: view, attribute: .leading, relatedBy: .equal, toItem: targetController.view, attribute: .leading, multiplier: 1, constant: 0)
        let right = NSLayoutConstraint(item: view, attribute: .trailing, relatedBy: .equal, toItem: targetController.view, attribute: .trailing, multiplier: 1, constant: 0)
        let top = NSLayoutConstraint(item: view, attribute: .top, relatedBy: .equal, toItem: targetController.view, attribute: .top, multiplier: 1, constant: 0)
        let bottom = NSLayoutConstraint(item: view, attribute: .bottom, relatedBy: .equal, toItem: targetController.view, attribute: .bottom, multiplier: 1, constant: 0)
        
        targetController.view.addConstraints([left, right, top, bottom])
    }
    
    // MARK: - Dispatch
    
    func dispatchMain(execute: @escaping ()->Void) {
        if Thread.isMainThread {
            execute()
        } else {
            DispatchQueue.main.async(execute: execute)
        }
    }
}
