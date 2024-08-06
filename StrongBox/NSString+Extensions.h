//
//  NSString__Extensions.h
//  Strongbox
//
//  Created by Strongbox on 02/05/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    kStringSearchMatchTypeNoMatch,
    kStringSearchMatchTypeExact,
    kStringSearchMatchTypeStartsWith,
    kStringSearchMatchTypeContains,
} StringSearchMatchType;
NS_ASSUME_NONNULL_BEGIN

@interface NSString (Extensions)

@property (readonly) NSData* sha1Data;
@property (readonly) NSData* sha256Data;

@property (readonly) NSString* trimmed;
@property (readonly) NSArray<NSString*>* lines;

@property (readonly, nullable) NSURL* urlExtendedParse;
@property (readonly, nullable) NSURL* urlExtendedParseAddingDefaultScheme;

@property (readonly) BOOL isHexString;
@property (readonly) BOOL isKeePassXmlBooleanStringTrue;
@property (readonly) BOOL isKeePassXmlBooleanStringFalse;
@property (readonly) BOOL isKeePassXmlBooleanStringNull;

@property (readonly, nullable) NSData* dataFromHex;
@property (readonly, nullable) NSData* dataFromBase32;
@property (readonly, nullable) NSData* dataFromBase64;
@property (readonly, nullable) NSData* utf8Data;

@property (readonly) BOOL isAllDigits;

- (StringSearchMatchType)isSearchMatch:(NSString*)searchText checkPinYin:(BOOL)checkPinYin;
- (BOOL)containsSearchString:(NSString*)searchText checkPinYin:(BOOL)checkPinYin;

- (NSString *)stringByTrimmingLeadingCharactersInSet:(NSCharacterSet *)characterSet;
- (NSString *)stringByTrimmingTrailingCharactersInSet:(NSCharacterSet *)characterSet;

@end

NS_ASSUME_NONNULL_END
