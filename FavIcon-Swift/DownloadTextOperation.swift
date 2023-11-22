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



final class DownloadTextOperation: URLRequestOperation {
    override func processResult(_ data: Data?, response: HTTPURLResponse, completion: @escaping (URLResult) -> Void) {
        let (mimeType, encoding) = response.contentTypeAndEncoding()
        if mimeType == "application/json" || mimeType.hasPrefix("text/") {
            if let data = data, let text = String(data: data, encoding: encoding) { 
                completion(.textDownloaded(url: response.url!, text: text, mimeType: mimeType))
            } else {
                completion(.failed(error: URLRequestError.invalidTextEncoding))
            }
        } else {
            completion(.failed(error: URLRequestError.notPlainText))
        }
    }
}
