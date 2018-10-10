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


#import "ODRequestOptionsBuilder.h"

@interface ODRequestOptionsBuilder()

@property (strong, nonatomic) NSMutableString *mutableQueryParams;

@property (strong, nonatomic) NSMutableDictionary *mutableHeaders;

@end

@implementation ODRequestOptionsBuilder

- (instancetype)init
{
    self = [super init];
    if (self){
        _mutableQueryParams = [NSMutableString stringWithFormat:@""];
        _mutableHeaders = [NSMutableDictionary dictionary];
    }
    return self;
}

+ (instancetype)optionsWithArray:(NSArray *)options
{
    __block ODRequestOptionsBuilder *optionsBuilder = [[ODRequestOptionsBuilder alloc] init];
    [options enumerateObjectsUsingBlock:^(ODRequestOptions *option, NSUInteger index, BOOL *stop){
        // it is possible this array has objects that are not of appendOptions type
        if ([option isKindOfClass:[ODRequestOptions class]]){
            [option appendOption:optionsBuilder.mutableHeaders queryParams:optionsBuilder.mutableQueryParams];
        }
    }];
    return optionsBuilder;
}

- (NSString *)queryOptions
{
    return _mutableQueryParams;
}

- (NSDictionary *)headers
{
    return _mutableHeaders;
}
@end
