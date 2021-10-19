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

import Foundation;


enum URLResult {

    
    
    
    
    case textDownloaded(url: URL, text: String, mimeType: String)

    
    
    
    case imageDownloaded(url: URL, image: ImageType)

    
    
    case success(url: URL)

    
    
    case failed(error: Error)

}


enum URLRequestError: Error {
    
    case missingResponse
    
    case fileNotFound
    
    case notPlainText
    
    case invalidTextEncoding
    
    case unsupportedImageFormat(mimeType: String)
    
    
    case httpError(response: HTTPURLResponse)
}


class URLRequestOperation: Operation {
    @objc var urlRequest: URLRequest
    var result: URLResult?

    fileprivate var task: URLSessionDataTask?
    fileprivate let session: URLSession
    fileprivate var semaphore: DispatchSemaphore?

    @objc init(url: URL, session: URLSession) {
        self.session = session
        self.urlRequest = URLRequest(url: url, timeoutInterval: 8.0) 
        self.semaphore = nil
    }

    override func main() {
        semaphore = DispatchSemaphore(value: 0)
        prepareRequest()
        task = session.dataTask(with: urlRequest, completionHandler: dataTaskCompletion)
        task?.resume()
        semaphore?.wait()
    }

    override func cancel() {
        task?.cancel()
        if let semaphore = semaphore {
            semaphore.signal()
        }
    }

    @objc func prepareRequest() {
    }

    func processResult(_ data: Data?, response: HTTPURLResponse, completion: @escaping (URLResult) -> Void) {
        fatalError("must override processResult()")
    }

    fileprivate func dataTaskCompletion(_ data: Data?, response: URLResponse?, error: Error?) {
        guard error == nil else {
            result = .failed(error: error!)
            self.notifyFinished()
            return
        }

        guard let response = response as? HTTPURLResponse else {
            result = .failed(error: URLRequestError.missingResponse)
            self.notifyFinished()
            return
        }

        if response.statusCode == 404 {
            result = .failed(error: URLRequestError.fileNotFound)
            self.notifyFinished()
            return
        }

        if response.statusCode < 200 || response.statusCode > 299 {
            result = .failed(error: URLRequestError.httpError(response: response))
            self.notifyFinished()
            return
        }

        processResult(data, response: response) { result in
            
            
            self.result = result
            self.notifyFinished()
        }
    }

    fileprivate func notifyFinished() {
        if let semaphore = self.semaphore {
            semaphore.signal()
        }
    }
}

typealias URLRequestWithCallback = (request: URLRequestOperation, completion: (URLResult) -> Void)

func executeURLOperations(_ operations: [URLRequestOperation],
                          concurrency: Int = 2,
                          on queue: OperationQueue? = nil,
                          completion: @escaping ([URLResult]) -> Void) {
    guard operations.count > 0 else {
        completion([])
        return
    }

    let queue = queue ?? OperationQueue()
    queue.isSuspended = true
    queue.maxConcurrentOperationCount = concurrency

    let completionOperation = BlockOperation {
        completion(operations.map { $0.result! })
    }
    for operation in operations {
        queue.addOperation(operation)
        completionOperation.addDependency(operation)
    }
    queue.addOperation(completionOperation)

    queue.isSuspended = false
}

func executeURLOperations(_ operations: [URLRequestWithCallback],
                          concurrency: Int = 2,
                          on queue: OperationQueue? = nil,
                          completion: @escaping () -> Void) {
    guard operations.count > 0 else { return }

    let queue = queue ?? OperationQueue()
    queue.isSuspended = true
    queue.maxConcurrentOperationCount = concurrency

    let overallCompletion = BlockOperation {
        completion()
    }

    for operation in operations {
        let operationCompletion = BlockOperation {
            operation.completion(operation.request.result!)
        }
        queue.addOperation(operation.request)
        operationCompletion.addDependency(operation.request)
        queue.addOperation(operationCompletion)
        overallCompletion.addDependency(operationCompletion)
    }
    queue.addOperation(overallCompletion)

    queue.isSuspended = false
}

func urlRequestOperation(_ operation: URLRequestOperation,
                         completion: @escaping (URLResult) -> Void) -> URLRequestWithCallback {
    return (request: operation, completion: completion)
}
