//
//  NSString__Extensions.m
//  Strongbox
//
//  Created by Strongbox on 02/05/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "NSString+Extensions.h"
#import "NSData+Extensions.h"

@implementation NSString (Extensions)

+ (NSRegularExpression *)urlRegex
{
    static NSRegularExpression *_regex;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        NSError* error;
    
        _regex = [NSRegularExpression regularExpressionWithPattern:@"^(([^:/?#]+):)?(//([^/?#]*))?([^?#]*)(\\?([^#]*))?(#(.*))?"
                                                           options:kNilOptions
                                                             error:&error];
        if(error) {
            NSLog(@"Error compiling Regex: %@", error);
        }
    });
    
    return _regex;
}

- (NSData*)sha1 {
    NSData* data = [self dataUsingEncoding:NSUTF8StringEncoding];
    return data.sha1;
}

- (NSData*)sha256 {
    NSData* data = [self dataUsingEncoding:NSUTF8StringEncoding];
    return data.sha256;
}

- (NSString *)trimmed {
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSArray<NSString *> *)lines {
     return [self componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
}

- (NSURL*)mmcgUrl { // TODO: Name Properly
    if (self.length == 0) {
        return nil;
    }
    // https://stackoverflow.com/a/26766402/3963806
    NSTextCheckingResult* result = [[NSString urlRegex] firstMatchInString:self options:kNilOptions range:NSMakeRange(0, self.length)];

    if (!result) {
        return nil;
    }
    
//    for(int i = 0;i<result.numberOfRanges;i++) {
//        NSRange range = [result rangeAtIndex:i];
//
//        if (range.location != NSNotFound) {
//            //NSLog(@"Range %d: [%@]", i, [self substringWithRange:range]);
//        }
//    }
    
    NSString* scheme = [result rangeAtIndex:2].location != NSNotFound ? [self substringWithRange:[result rangeAtIndex:2]] : @"";
    NSString* host =  [result rangeAtIndex:4].location != NSNotFound ? [self substringWithRange:[result rangeAtIndex:4]] : @"";
    NSString* path =  [result rangeAtIndex:5].location != NSNotFound ? [self substringWithRange:[result rangeAtIndex:5]] : @"";
    NSString* query =  [result rangeAtIndex:7].location != NSNotFound ? [self substringWithRange:[result rangeAtIndex:7]] : nil;
    NSString* fragment =  [result rangeAtIndex:9].location != NSNotFound ? [self substringWithRange:[result rangeAtIndex:9]] : nil;

    NSURLComponents *components = [[NSURLComponents alloc] init];
    
    components.scheme = scheme;
    components.host = host;
    components.path = path;
    components.query = query;
    components.fragment = fragment;
    
//    NSLog(@"Built: [%@]", components.URL);
    
    // TODO:
    
//    @property (nullable, copy) NSString *user;
//    @property (nullable, copy) NSString *password;
//    @property (nullable, copy) NSString *host;
//    @property (nullable, copy) NSNumber *port; // Attempting to set a negative port number will cause an exception.

    
    return components.URL;

}

@end
