//
// FavIcon
// Copyright © 2016 Leon Breedt
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software






import Foundation

extension String {
    
    
    func parseAsHTTPContentTypeHeader() -> (mimeType: String, encoding: String.Encoding) {
        let headerComponents =
            components(separatedBy: ";")
                .map { $0.trimmingCharacters(in: .whitespaces) }

        if headerComponents.count > 1 {
            let parameters =
                headerComponents[1 ..< headerComponents.count]
                    .filter { $0.contains("=") }
                    .map { $0.components(separatedBy: "=") }
                    .toDictionary { ($0[0], $0[1]) }

            
            
            var encoding = String.Encoding.utf8
            if let charset = parameters["charset"], let parsedEncoding = charset.parseAsStringEncoding() {
                encoding = parsedEncoding
            }

            return (mimeType: headerComponents[0], encoding: encoding)
        } else {
            return (mimeType: headerComponents[0], encoding: String.Encoding.utf8)
        }
    }

    
    
    
    func parseAsStringEncoding() -> String.Encoding? {
        switch lowercased() {
        case "iso-8859-1", "latin1": return String.Encoding.isoLatin1
        case "iso-8859-2", "latin2": return String.Encoding.isoLatin2
        case "iso-2022-jp": return String.Encoding.iso2022JP
        case "shift_jis": return String.Encoding.shiftJIS
        case "us-ascii": return String.Encoding.ascii
        case "utf-8": return String.Encoding.utf8
        case "utf-16": return String.Encoding.utf16
        case "utf-32": return String.Encoding.utf32
        case "utf-32be": return String.Encoding.utf32BigEndian
        case "utf-32le": return String.Encoding.utf32LittleEndian
        case "windows-1250": return String.Encoding.windowsCP1250
        case "windows-1251": return String.Encoding.windowsCP1251
        case "windows-1252": return String.Encoding.windowsCP1252
        case "windows-1253": return String.Encoding.windowsCP1253
        case "windows-1254": return String.Encoding.windowsCP1254
        case "x-mac-roman": return String.Encoding.macOSRoman
        default:
            return nil
        }
    }
    
}

extension HTTPURLResponse {
    
    
    func contentTypeAndEncoding() -> (mimeType: String, encoding: String.Encoding) {
        if let contentTypeHeader = allHeaderFields["Content-Type"] as? String {
            return contentTypeHeader.parseAsHTTPContentTypeHeader()
        }
        return (mimeType: "application/octet-stream", encoding: String.Encoding.utf8)
    }
}

extension Array {
    
    
    
    
    
    func toDictionary<K, V>(_ transform: (Element) -> (K, V)) -> [K: V] {
        var dict: [K: V] = [:]
        for item in self {
            let (key, value) = transform(item)
            dict[key] = value
        }
        return dict
    }
}
