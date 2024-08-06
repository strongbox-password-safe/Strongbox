//
//  MarkdownCocoaTableCellView.swift
//  test-libcmark-gfm
//
//  Created by Strongbox on 08/11/2023.
//

import Cocoa
import WebKit

class MarkdownCocoaTableCellView: NSTableCellView, WKNavigationDelegate {
    @IBOutlet var heightConstraint: NSLayoutConstraint!

    static let NibIdentifier: NSUserInterfaceItemIdentifier = .init("MarkdownCocoaTableCellView")

    static let resourcesUrl: URL = {
        let resourcesUrl = Bundle.main.resourceURL

        if resourcesUrl == nil {
            swlog("🔴 Could not get Bundle Resources URL in MarkdownCocoaTableCellView")
        }

        return resourcesUrl!
    }()

    @IBOutlet var webView: StrongboxCocoaWebKitView!

    override func awakeFromNib() {
        super.awakeFromNib()



        webView.navigationDelegate = self








    }

    @objc
    public func setContent(html: String) {
        webView.loadHTMLString(html, baseURL: MarkdownCocoaTableCellView.resourcesUrl)
    }

    func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        webView.isHidden = false

        

        self.webView.evaluateJavaScript("document.readyState", completionHandler: { complete, error in
            if complete != nil {
                self.webView.evaluateJavaScript("document.body.scrollHeight", completionHandler: { [weak self] maybeHeight, error in
                    if error != nil {
                        swlog("🔴 Javascript height measure failed: [%@]", String(describing: error))
                        return
                    }

                    guard let self else { return }

                    if let height = maybeHeight as? CGFloat {
                        

                        if self.heightConstraint.constant != height {
                            self.heightConstraint.constant = height
                        }
                    }
                })
            } else {
                swlog("🔴 Javascript did not complete: [%@]", String(describing: error))
            }
        })
    }

    func webView(_: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void)
    {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        if url.scheme != "about", url.scheme != "file" {
            decisionHandler(.cancel)
            NSWorkspace.shared.open(url)
        } else {
            decisionHandler(.allow)
        }
    }
}
















































