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


final class CheckURLExistsOperation: URLRequestOperation {
    override func prepareRequest() {
        urlRequest.httpMethod = "GET"
    }

    override func processResult(_: Data?, response: HTTPURLResponse, completion: @escaping (URLResult) -> Void) {
        completion(.success(url: response.url!))
    }
}
