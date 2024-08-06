//
//  MarkdownUIKitTableCellView.swift
//  test-libcmark-gfm-ios
//
//  Created by Strongbox on 08/11/2023.
//

import UIKit
import WebKit

@objc
public class MarkdownUIKitTableCellView: UITableViewCell, WKNavigationDelegate {
    @IBOutlet var heightConstraint: NSLayoutConstraint!
    @IBOutlet var webView: WKWebView!

    static let resourcesUrl: URL = {
        let resourcesUrl = Bundle.main.resourceURL

        if resourcesUrl == nil {
            swlog("🔴 Could not get Bundle Resources URL in MarkdownUIKitTableCellView")
        }

        return resourcesUrl!
    }()

    var doubleTap: UITapGestureRecognizer? = nil
    override public func awakeFromNib() {
        super.awakeFromNib()

        webView.isHidden = true
        webView.navigationDelegate = self
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
    }

    var onHeightChanged: (() -> Void)? = nil

    @objc
    public func setContent(html: String, onHeightChanged: (() -> Void)? = nil) {
        self.onHeightChanged = onHeightChanged

        webView.loadHTMLString(html, baseURL: MarkdownUIKitTableCellView.resourcesUrl)
    }

    public func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
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




                            self.onHeightChanged?()

                        }
                    }
                })
            } else {
                swlog("🔴 Javascript did not complete: [%@]", String(describing: error))
            }
        })
    }

    public func webView(_: WKWebView,
                        decidePolicyFor navigationAction: WKNavigationAction,
                        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void)
    {
        let url = navigationAction.request.url
        

        if let url, url.scheme != "about", url.scheme != "file" {
            decisionHandler(.cancel)
            #if IS_APP_EXTENSION
            
            #else
                UIApplication.shared.open(url)
            #endif
        } else {
            decisionHandler(.allow)
        }
    }
}
