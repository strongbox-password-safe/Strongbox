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
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

extension String {
    /// Parses this string as an HTTP Content-Type header.
    /// - returns: A tuple containing the mime type and string, if this could be determined.
    func parseAsHTTPContentTypeHeader() -> (mimeType: String, encoding: String.Encoding) {
        let headerComponents =
            components(separatedBy: ";")
                .map { $0.trimmingCharacters(in: .whitespaces) }

        if headerComponents.count > 1 {
            let parameters =
                headerComponents[1..<headerComponents.count]
                    .filter { $0.contains("=") }
                    .map { $0.components(separatedBy: "=") }
                    .toDictionary { ($0[0], $0[1]) }

            // Default according to RFC is ISO-8859-1, but probably nothing obeys that, so default
            // to UTF-8 instead.
            var encoding = String.Encoding.utf8
            if let charset = parameters["charset"], let parsedEncoding = charset.parseAsStringEncoding() {
                encoding = parsedEncoding
            }

            return (mimeType: headerComponents[0], encoding: encoding)
        } else {
            return (mimeType: headerComponents[0], encoding: String.Encoding.utf8)
        }
    }

    /// - Returns: The Cocoa encoding identifier for the encoding name in this string, or `nil`
    ///            if the encoding is not supported or known.
    //swiftlint:disable cyclomatic_complexity
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
    //swiftlint:enable cyclomatic_complexity
}

extension HTTPURLResponse {
    /// Parses the `Content-Type` header in this response.
    /// - returns: A `(mimeType: String, encoding: String.Encoding)` tuple.
    func contentTypeAndEncoding() -> (mimeType: String, encoding: String.Encoding) {
        if let contentTypeHeader = allHeaderFields["Content-Type"] as? String {
            return contentTypeHeader.parseAsHTTPContentTypeHeader()
        }
        return (mimeType: "application/octet-stream", encoding: String.Encoding.utf8)
    }
}

extension Array {
    /// Converts this array to a dictionary of type `[K: V]`, by calling a transform closure to
    /// obtain a key and a value from an array element.
    /// - parameter transform: A closure that will transform an array element of type `Element` into a
    ///                        `(K, V)` tuple.
    /// - returns: A dictionary having items of type `K` as keys, and type `V` as values.
    func toDictionary<K, V>(_ transform: (Element) -> (K, V)) -> [K: V] {
        var dict: [K: V] = [:]
        for item in self {
            let (key, value) = transform(item)
            dict[key] = value
        }
        return dict
    }
}
