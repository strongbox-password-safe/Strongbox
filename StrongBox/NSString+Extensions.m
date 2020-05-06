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

@end
