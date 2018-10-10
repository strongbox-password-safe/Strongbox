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


#import "ODObject.h"

/**
 An `ODCollection` object is a collection of OneDrive objects.
 @see ODObject
 */
@interface ODCollection : NSObject

/**
 An array of OneDrive objects.
 */
@property (strong, nonatomic) NSArray *value;

/**
 There may be more items in the collection available via paging. This is the url to the next page of the collection.
 */
@property (strong, nonatomic) NSURL *nextLink;

/**
 Any additional data returned from the collection request will be in this dictionary.
 */
@property (strong, nonatomic) NSDictionary *additionalData;

/**
 Creates an ODCollection with the response from the service.
 @param array The array of OneDrive objects.
 @param nextLink The link to the next page of items, if there is one.
 @param additionalData Any other data returned from the service.
 */
- (instancetype)initWithArray:(NSArray *)array
                     nextLink:(NSString *)nextLink
               additionalData:(NSDictionary *)additionalData;

@end
