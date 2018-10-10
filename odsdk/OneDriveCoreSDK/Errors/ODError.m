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


#import "ODError.h"

static NSString *const code = @"code";
static NSString *const message = @"message";
static NSString *const innerError = @"innererror";

@implementation ODError

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    // any error dictionary that doesn't contain a code is malformed
    self = [super init];
    if (self){
        if (dictionary && dictionary[code]){
            _code = dictionary[code];
            _message = dictionary[message];
            if (dictionary[innerError]){
                _innerError = [ODError errorWithDictionary:dictionary[innerError]];
            }
        }
        else{
            _code = ODMalformedErrorResponseError;
        }
    }
    return self;
}

+ (instancetype)errorWithDictionary:(NSDictionary *)dictionary
{
    return [[ODError alloc] initWithDictionary:dictionary];
}

- (BOOL)matches:(NSString *)code
{
    BOOL matches = NO;
    // start at the inner most error
    if (self.innerError){
        matches = [self.innerError matches:code];
    }
    if (!matches){
        matches = [self.code isEqualToString:code];
    }
    return matches;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@" %@ : %@", self.code, self.message];
}

@end
