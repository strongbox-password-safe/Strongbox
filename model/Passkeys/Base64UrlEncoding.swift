//
//  Base64UrlEncoding.swift
//  Strongbox
//
//  Created by Strongbox on 09/09/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

@objc
class Base64UrlEncoding: NSObject {
    static func dataToBase64UrlEncoding(_ data: Data) -> String {
        base64ToBase64Url(data.base64EncodedString())
    }

    static func base64UrlEncodingToData(_ string: String) -> Data? {
        Data(base64Encoded: base64UrlToBase64(string), options: .ignoreUnknownCharacters)
    }

    static func base64UrlToBase64(_ base64url: String) -> String {
        var base64 = base64url
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        if base64.count % 4 != 0 {
            base64.append(String(repeating: "=", count: 4 - base64.count % 4))
        }

        return base64
    }

    static func base64ToBase64Url(_ base64: String) -> String {
        let base64url = base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        return base64url
    }
}
