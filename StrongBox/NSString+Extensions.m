//
//  NSString__Extensions.m
//  Strongbox
//
//  Created by Strongbox on 02/05/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "NSString+Extensions.h"
#import "NSData+Extensions.h"

static NSString* const kDefaultScheme = @"https";

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
            NSLog(@"Error compiling Regex: %@", error);
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
            NSLog(@"Error compiling Regex: %@", error);
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
            NSLog(@"Error compiling host Regex: %@", error);
        }
    });
    
    return _hostRegex;
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
            NSLog(@"hostResult Range %d: [%@]", i, [host substringWithRange:range]);
        }
    }
    
    NSString* processedHost =  [hostResult rangeAtIndex:5].location != NSNotFound ? [host substringWithRange:[hostResult rangeAtIndex:5]] : host;
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
        NSLog(@"Exception while building URL: [%@]", exception);
        return nil;
    } @finally {
        
    }
    
    NSLog(@"Built: [%@]", components.URL);
    
    return components.URL;
}

- (BOOL)isHexString {
    NSTextCheckingResult* result = [[NSString isHexStringRegex] firstMatchInString:self options:kNilOptions range:NSMakeRange(0, self.length)];
    
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

@end
