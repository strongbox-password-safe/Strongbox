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

// Attempts to download the text content for a URL, and returns
// `URLResult.TextDownloaded` as the result if it does.
final class DownloadTextOperation: URLRequestOperation {
    override func processResult(_ data: Data?, response: HTTPURLResponse, completion: @escaping (URLResult) -> Void) {
        let (mimeType, encoding) = response.contentTypeAndEncoding()
        if mimeType == "application/json" || mimeType.hasPrefix("text/") {
            if let data = data, let text = String(data: data, encoding: encoding) { //  ?? String.Encoding.utf8
                completion(.textDownloaded(url: response.url!, text: text, mimeType: mimeType))
            } else {
                completion(.failed(error: URLRequestError.invalidTextEncoding))
            }
        } else {
            completion(.failed(error: URLRequestError.notPlainText))
        }
    }
}
