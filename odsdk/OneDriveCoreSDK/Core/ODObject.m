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
#import "NSDate+ODSerialization.h"

@interface ODObject()

@property (strong, nonatomic) NSMutableDictionary *dictionary;

@end

@implementation ODObject

- (instancetype)init
{
    self = [super init];
    if (self){
        _dictionary = [NSMutableDictionary dictionary];
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary*)dictionary
{
    // if there is no dictionary we don't want to create the object
    if (!dictionary){
        return nil;
    }
    self = [super init];
    if (self){
        _dictionary = [dictionary mutableCopy];
    }
    return self;
}

- (NSDictionary*)dictionaryFromItem
{
    NSMutableDictionary *fullDictionary = [NSMutableDictionary dictionary];
    [self.dictionary enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop){
        if ([obj respondsToSelector:@selector(dictionaryFromItem)]){
            fullDictionary[key] = [obj dictionaryFromItem];
        }
        else if ([obj respondsToSelector:@selector(od_toString)]){
            fullDictionary[key] = [obj od_toString];
        }
        else{
            fullDictionary[key] = obj;
        }
    }];
    return fullDictionary;
}

- (NSDate *)dateFromString:(NSString *)dateString
{
    return [NSDate od_dateFromString:dateString];
}

- (NSString *)description
{
    return [[self dictionaryFromItem] description];
}

@end


