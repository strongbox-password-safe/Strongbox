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
 The `ODObject` is the base class for all OneDrive objects.
 @see ODItem for an example.
 */
@interface ODObject : NSObject

/**
 Creates an ODObject with the given dictionary.
 @param dictionary The dictionary representation of the object.
 @warning This method will return nil if the dictionary is nil.
 */
- (instancetype)initWithDictionary:(NSDictionary*)dictionary;

/**
 Creates a dictionary from the given item.
 @return dictionary Representation for the given item.
 */
- (NSDictionary*)dictionaryFromItem;

/**
 Creates an NSDate from a string returned by the server.
 @param A date string in ISO 1601 format.
 @return An NSDate object of the string.
 */
- (NSDate *)dateFromString:(NSString *)dateString;

@end
