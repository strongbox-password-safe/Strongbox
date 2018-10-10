//  Copyright 2015 Microsoft Corporation
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//  
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "ODHttpProvider.h"
/**
 * 'ODURLSessionManager' manages all Http access from the OneDrive SDK, it conforms to the ODHttpProvider protocol
 */
@interface ODURLSessionManager : NSObject <ODHttpProvider,
                                            NSURLSessionDelegate,
                                            NSURLSessionDataDelegate,
                                            NSURLSessionTaskDelegate,
                                            NSURLSessionDownloadDelegate>

/**
 *  Creates an instance of ODURLSessionManager with the given configuration.
 *  @param  urlSessionConfiguration the session configuration to use
 *  @return the instance of ODURLSessionManager
 *  @warning the ODURLSessionManager currently uses the same NSURLSession for data/download/upload tasks.  
 *           If you use a background session you must be sure to not invoke any data requests.
 */
- (instancetype)initWithSessionConfiguration:(NSURLSessionConfiguration *)urlSessionConfiguration;

@end
