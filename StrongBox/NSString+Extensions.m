//
//  NSString__Extensions.m
//  Strongbox
//
//  Created by Strongbox on 02/05/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "NSString+Extensions.h"
#import "NSData+Extensions.h"
#import "MMcG_MF_Base32Additions.h"
#import "SBLog.h"

static NSString* const kDefaultScheme = @"https";
static NSString* const kDefaultSchemeWithSlashes = @"https://";

static NSString* const kLowerCaseTrue = @"true";
static NSString* const kLowerCaseFalse = @"false";
static NSString* const kLowerCaseNull = @"null";

@implementation NSString (Extensions)

+ (NSRegularExpression *)urlRegex {
    static NSRegularExpression *_regex;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        NSError* error;
    
        

        _regex = [NSRegularExpression regularExpressionWithPattern:@"^(([^:/?#]+):)?(
                                                           options:kNilOptions
                                                             error:&error];

        if(error) {
            slog(@"Error compiling Regex: %@", error);
        }
    });
    
    return _regex;
}

+ (NSRegularExpression *)isHexStringRegex {
    static NSRegularExpression *_regex;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        NSError* error;

        _regex = [NSRegularExpression regularExpressionWithPattern:@"^[0-9A-Fa-f]*$"
                                                           options:kNilOptions
                                                             error:&error];

        if(error) {
            slog(@"Error compiling Regex: %@", error);
        }
    });
    
    return _regex;
}

+ (NSRegularExpression *)hostRegex {
    static NSRegularExpression *_hostRegex;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        NSError* error;
    
        _hostRegex = [NSRegularExpression regularExpressionWithPattern:@"^((.+?)(:(.+?))?@)?(.+?)(:([0-9]+))?$"
                                                           options:kNilOptions
                                                             error:&error];

        if(error) {
            slog(@"Error compiling host Regex: %@", error);
        }
    });
    
    return _hostRegex;
}

+ (NSRegularExpression *)hanChineseRegex {
    static NSRegularExpression *hanChineseRegex;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        NSError* error;
    
        hanChineseRegex = [NSRegularExpression regularExpressionWithPattern:@"\\p{Script=Han}" options:NSRegularExpressionCaseInsensitive error:&error];

        if(error) {
            slog(@"Error compiling hanChineseRegex: %@", error);
        }
    });
    
    return hanChineseRegex;
}

- (NSData*)sha1Data {
    NSData* data = [self dataUsingEncoding:NSUTF8StringEncoding];
    
    return data.sha1;
}

- (NSData*)sha256Data {
    NSData* data = [self dataUsingEncoding:NSUTF8StringEncoding];
    return data.sha256;
}

- (NSString *)trimmed {
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSArray<NSString *> *)lines {
     return [self componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
}

- (NSURL *)urlExtendedParseAddingDefaultScheme {
    NSURL* url = self.urlExtendedParse;
    
    if ( url && url.scheme.length == 0 ) {
        NSString* foo = [kDefaultSchemeWithSlashes stringByAppendingString:url.absoluteString];
        return foo.urlExtendedParse;
    }
    
    return url;
}

- (NSURL*)urlExtendedParse {
    NSURL *simple = [NSURL URLWithString:self];
    if (simple) {
        return simple;
    }
    
    if (self.length == 0) {
        return nil;
    }
    
    NSTextCheckingResult* result = [[NSString urlRegex] firstMatchInString:self options:kNilOptions range:NSMakeRange(0, self.length)];

    if (!result) {
        return nil;
    }
    








    NSString* scheme = [result rangeAtIndex:2].location != NSNotFound ? [self substringWithRange:[result rangeAtIndex:2]] : kDefaultScheme;
    NSString* host =  [result rangeAtIndex:4].location != NSNotFound ? [self substringWithRange:[result rangeAtIndex:4]] : @"";
    NSString* path =  [result rangeAtIndex:5].location != NSNotFound ? [self substringWithRange:[result rangeAtIndex:5]] : @"";
    NSString* query =  [result rangeAtIndex:7].location != NSNotFound ? [self substringWithRange:[result rangeAtIndex:7]] : nil;
    NSString* fragment =  [result rangeAtIndex:9].location != NSNotFound ? [self substringWithRange:[result rangeAtIndex:9]] : nil;

    
    
    NSTextCheckingResult* hostResult = [[NSString hostRegex] firstMatchInString:host options:kNilOptions range:NSMakeRange(0, host.length)];
    if (!hostResult) {
        return nil;
    }
    
    for(int i = 0;i<hostResult.numberOfRanges;i++) {
        NSRange range = [hostResult rangeAtIndex:i];

        if (range.location != NSNotFound) {

        }
    }
    
    NSString* processedHost =  [hostResult rangeAtIndex:5].location != NSNotFound ? [host substringWithRange:[hostResult rangeAtIndex:5]] : host;
    
    processedHost = [host stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLHostAllowedCharacterSet]; 
    
    NSString* username =  [hostResult rangeAtIndex:2].location != NSNotFound ? [host substringWithRange:[hostResult rangeAtIndex:2]] : nil;
    NSString* password =  [hostResult rangeAtIndex:4].location != NSNotFound ? [host substringWithRange:[hostResult rangeAtIndex:4]] : nil;
    NSString* port =  [hostResult rangeAtIndex:7].location != NSNotFound ? [host substringWithRange:[hostResult rangeAtIndex:7]] : nil;
    
    NSURLComponents *components = [[NSURLComponents alloc] init];

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    @try {
        components.scheme = scheme;
        components.host = processedHost;
        components.path = path;
        components.query = query;
        components.fragment = fragment;
        components.user = username;
        components.password = password;
        components.port = port ? @(port.integerValue) : nil;
    } @catch (NSException *exception) {
        slog(@"Exception while building URL: [%@]", exception);
        return nil;
    } @finally {
        
    }
    

    
    return components.URL;
}

- (BOOL)isHexString {
    NSString* string = [[self componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] componentsJoinedByString:@""];
    NSTextCheckingResult* result = [[NSString isHexStringRegex] firstMatchInString:string options:kNilOptions range:NSMakeRange(0, string.length)];
    
    if (!result) {
        return NO;
    }

    return YES;
}

- (BOOL)isKeePassXmlBooleanStringTrue {
    return [self.lowercaseString isEqualToString:kLowerCaseTrue] || [self.lowercaseString isEqualToString:@"1"];
}

- (BOOL)isKeePassXmlBooleanStringFalse {
    return [self.lowercaseString isEqualToString:kLowerCaseFalse] || [self.lowercaseString isEqualToString:@"0"];
}

- (BOOL)isKeePassXmlBooleanStringNull {
    return [self.lowercaseString isEqualToString:kLowerCaseNull];
}

- (NSData *)dataFromHex {
    NSString* string = [[self componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] componentsJoinedByString:@""];
        
    const char *chars = [string UTF8String];
    NSUInteger i = 0, len = string.length;
    
    NSMutableData *data = [NSMutableData dataWithCapacity:len / 2];
    char byteChars[3] = {'\0','\0','\0'};
    unsigned long wholeByte;
    
    while (i < len) {
        byteChars[0] = chars[i++];
        byteChars[1] = chars[i++];
        wholeByte = strtoul(byteChars, NULL, 16);
        [data appendBytes:&wholeByte length:1];
    }
    
    return data.copy;
}

- (NSData *)dataFromBase32 {
    return [NSData mmcg_dataWithBase32String:self];
}

- (NSData *)dataFromBase64 {
    return [[NSData alloc] initWithBase64EncodedString:self options:NSDataBase64DecodingIgnoreUnknownCharacters];
}

- (NSData *)utf8Data {
    return [self dataUsingEncoding:NSUTF8StringEncoding];
}

- (StringSearchMatchType)isSearchMatch:(NSString*)searchText checkPinYin:(BOOL)checkPinYin {
    if ( self.length == 0 || searchText.length == 0) {
        return kStringSearchMatchTypeNoMatch;
    }

    if ( self == searchText || ( [self localizedCaseInsensitiveCompare:searchText] == NSOrderedSame ) ) {
        return kStringSearchMatchTypeExact;
    }
    
    NSRange range = [self rangeOfString:searchText options:NSCaseInsensitiveSearch | NSAnchoredSearch | NSDiacriticInsensitiveSearch];
    if ( range.location != NSNotFound ) {
        return kStringSearchMatchTypeStartsWith;
    }
    
    BOOL contains = [self containsSearchString:searchText checkPinYin:checkPinYin];
    
    return contains ? kStringSearchMatchTypeContains : kStringSearchMatchTypeNoMatch;
}

- (BOOL)containsSearchString:(NSString*)searchText checkPinYin:(BOOL)checkPinYin {
    if ( self.length == 0 || searchText.length == 0) {
        return NO;
    }
    
    BOOL simple = [self localizedStandardContainsString:searchText];

    if ( simple ) {
        return YES;
    }
    
    if ( !checkPinYin ) {
        return NO;
    }
    
    
    
    
    
    NSTextCheckingResult* result = [[NSString hanChineseRegex] firstMatchInString:self options:kNilOptions range:NSMakeRange(0, self.length)];
    
    if ( result ) {
        
        
        
        
        NSMutableString* latinized = self.mutableCopy;
        CFStringTransform((__bridge CFMutableStringRef)latinized, nil, kCFStringTransformMandarinLatin, NO);
        CFStringTransform((__bridge CFMutableStringRef)latinized, nil, kCFStringTransformStripDiacritics, NO);

        NSString* pinYinStr = [latinized stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        pinYinStr = [pinYinStr stringByReplacingOccurrencesOfString:@"\r" withString:@""];
        pinYinStr = [pinYinStr stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        pinYinStr = [pinYinStr stringByReplacingOccurrencesOfString:@" " withString:@""];

        

        BOOL latinizedPinYin = [pinYinStr localizedStandardContainsString:searchText];

        return latinizedPinYin;
    }
    
    return NO;
}

- (void)enumerateCharactersWithBlock:(void (^)(unichar, NSUInteger, BOOL *))block {
    
    const NSInteger bufferSize = 16;
    const NSInteger length = [self length];
    unichar buffer[bufferSize];
    NSInteger bufferLoops = (length - 1) / bufferSize + 1;
    BOOL stop = NO;
    for (int i = 0; i < bufferLoops; i++) {
        NSInteger bufferOffset = i * bufferSize;
        NSInteger charsInBuffer = MIN(length - bufferOffset, bufferSize);
        [self getCharacters:buffer range:NSMakeRange(bufferOffset, charsInBuffer)];
        for (int j = 0; j < charsInBuffer; j++) {
            block(buffer[j], j + bufferOffset, &stop);
            if (stop) {
                return;
            }
        }
    }
}

- (BOOL)isAllDigits {
    NSCharacterSet* nonNumbers = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    NSRange r = [self rangeOfCharacterFromSet:nonNumbers];
    return r.location == NSNotFound && self.length > 0;
}

- (NSString *)stringByTrimmingLeadingCharactersInSet:(NSCharacterSet *)characterSet {
    NSRange rangeOfFirstWantedCharacter = [self rangeOfCharacterFromSet:[characterSet invertedSet]];
    
    if (rangeOfFirstWantedCharacter.location == NSNotFound) {
        return @"";
    }
    
    return [self substringFromIndex:rangeOfFirstWantedCharacter.location];
}

- (NSString *)stringByTrimmingTrailingCharactersInSet:(NSCharacterSet *)characterSet {
    NSRange rangeOfLastWantedCharacter = [self rangeOfCharacterFromSet:[characterSet invertedSet]
                                                               options:NSBackwardsSearch];
    if (rangeOfLastWantedCharacter.location == NSNotFound) {
        return @"";
    }
    
    return [self substringToIndex:rangeOfLastWantedCharacter.location+1]; 
}

@end
