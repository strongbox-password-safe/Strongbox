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

/**
 `ODRequestOptions` will store a key value pair used to append to a request
 ##Subclassing Notes
 Subclassed by ODQueryParameters and ODHeaderOptions
 @warning When subclassing you MUST implement appendOptions:queryParams:
 
 @see ODQueryParameters
 @see ODHeaderOptions
 */
@interface ODRequestOptions : NSObject

/**
 The key of the option
 */
@property (strong, nonatomic) NSString *key;

/**
 The value of the option
 */
@property (strong, nonatomic) NSString *value;

/**
 Creates an instance of an `ODRequestOptions` object
 @param key the key of the option
 @param value the value of the option
 */
- (instancetype)initWithKey:(NSString *)key value:(NSString *)value;

/**
 appends the query parameters to the string or adds the header to the headers
 @param headers the headers dictionary to append to
 @param queryParams the mutable string to append to
 */
- (void)appendOption:(NSMutableDictionary *)headers queryParams:(NSMutableString *)queryParams;

@end

