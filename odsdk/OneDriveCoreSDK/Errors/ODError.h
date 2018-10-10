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

#import <Foundation/Foundation.h>

#import "ODErrorCodes.h"

/**
 This class is used to represent client errors from the OneDrive service
 @see https://github.com/OneDrive/onedrive-api-docs/blob/master/misc/errors.md for more information
 @see ODErrorCodes.h for specific error codes
 */
@interface ODError : NSObject
/**
 Creates an ODError with the given dictionary
 @param dictionary the error dictionary
 */
+ (instancetype)errorWithDictionary:(NSDictionary *)dictionary;

/**
 The error code returned from the service
 @see ODErrorCodes.h for errors
 */
@property NSString *code;

/**
 The message from the error, this is not to be displayed to the user
 */
@property NSString *message;

/**
 The inner error may contain more detailed information about the error
 */
@property ODError *innerError;

/**
 @param code the error code
 @return YES if the code matches the error or one of the inner errors
 @return NO if the code doesn't match the error or any of its inner errors
 @see ODErrorCodes.h
 */
- (BOOL)matches:(NSString*)code;

@end
