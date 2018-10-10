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


#import "ODClient+HelperMethods.h"
#import "ODDriveRequestBuilder.h"
#import "ODAuthProvider.h"

@implementation ODClient (HelperMethods)


- (ODDriveRequestBuilder *)drive
{
    return [[ODDriveRequestBuilder alloc] initWithURL:[self.baseURL URLByAppendingPathComponent:@"drive/"] client:self];
}

- (ODItemRequestBuilder *)root
{
    return [[self drive] items:@"root"];
}

- (void)signOutWithCompletion:(void (^)(NSError *error))completionHandler
{
    if ([self.authProvider respondsToSelector:@selector(signOutWithCompletion:)]){
        [self.authProvider signOutWithCompletion:completionHandler];
    }
    else{
        [self.logger logWithLevel:ODLogWarn message:@"Authentication provider doesn't respond to signOutWithCompletion"];
        if (completionHandler) {
            completionHandler(nil);
        }
    }
}

- (NSDictionary *)serviceFlags
{
    return self.authProvider.serviceFlags;
}

@end
