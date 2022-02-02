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

import Foundation





final class DownloadImageOperation: URLRequestOperation {
    override func processResult(_ data: Data?, response: HTTPURLResponse, completion: @escaping (URLResult) -> Void) {
        guard let data = data else {
            completion(.failed(error: URLRequestError.missingResponse))
            return
        }

        let (mimeType, _) = response.contentTypeAndEncoding()
        switch mimeType {
        case "image/png", "image/jpg", "image/jpeg", "image/x-icon", "image/vnd.microsoft.icon":
            
            DispatchQueue.main.async {
                var result: URLResult
                if let image = ImageType(data: data) {
                    result = .imageDownloaded(url: response.url!, image: image)
                } else {
                    result = .failed(error: URLRequestError.unsupportedImageFormat(mimeType: mimeType))
                }
                completion(result)
            }
            return
        default:
            completion(.failed(error: URLRequestError.unsupportedImageFormat(mimeType: mimeType)))
            return
        }
    }
}
