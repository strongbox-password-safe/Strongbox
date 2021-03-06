//
//  KeyFileParser.m
//  Strongbox
//
//  Created by Mark on 04/12/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "KeyFileParser.h"
#import "NSData+Extensions.h"
#import "NSArray+Extensions.h"
#import "NSString+Extensions.h"

#if TARGET_OS_IPHONE
#import "KissXML.h" // Drop in replacements for the NSXML stuff available on Mac
#endif

static NSString* const kKeyFileRootElementName = @"KeyFile";
static NSString* const kKeyElementName = @"Key";
static NSString* const kDataElementName = @"Data";
static NSString* const kMetaElementName = @"Meta";
static NSString* const kVersionElementName = @"Version";
static NSString* const kHashAttributeName = @"Hash";

@implementation KeyFileParser

+ (NSData *)getKeyFileDigestFromFileData:(NSData *)data checkForXml:(BOOL)checkForXml {
    if(!data) {
        return nil;
    }

    
    
    
    
    if(checkForXml) {
        NSData* xml = [KeyFileParser getXmlKey:data];
        if(xml) {
            return xml;
        }
    }
    
    

    if (data.length == 32) {
        return data;
    }

    

    NSData* textHex = [KeyFileParser getHexTextKey:data];
    if(textHex) {
        return textHex;
    }
    
    

    return data.sha256;
}

+ (NSData*)getHexTextKey:(NSData*)data {
    if(isAll64CharactersAreHex(data)) {
        NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        
        return [KeyFileParser dataWithHexString:text];
    }

    return nil;
}

BOOL isAll64CharactersAreHex(NSData* data) {
    const int BUF_LEN = 64;
    
    if(data.length != BUF_LEN) {
        return NO;
    }
    
    unsigned char buf[BUF_LEN];
    [data getBytes:buf range:NSMakeRange(0, BUF_LEN)];
    
    for(int i=0;i<BUF_LEN;i++) {
        if(!ishexnumber(buf[i])) {
            return NO;
        }
    }
    
    return YES;
}

+(NSData*)dataWithHexString:(NSString *)hex {
    char buf[3];
    buf[2] = '\0';
    
    if(0 != [hex length] % 2) {
        return nil;
    }
    
    NSMutableData* ret = [NSMutableData dataWithLength:hex.length/2];
    
    unsigned char *bp = ret.mutableBytes;
    for (CFIndex i = 0; i < [hex length]; i += 2) {
        buf[0] = [hex characterAtIndex:i];
        buf[1] = [hex characterAtIndex:i+1];
        char *b2 = NULL;
        *bp++ = strtol(buf, &b2, 16);
        
        if(b2 != buf + 2) {
            return nil;
        }
    }

    return ret;
}

+ (NSData*)getXmlKey:(NSData*)data {
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    

    NSError *error;
    NSXMLDocument *document = [[NSXMLDocument alloc] initWithData:data options:kNilOptions error:&error];
    
    if(!document || error != nil) {
        
        return nil;
    }
    
    if(!document.rootDocument || document.rootDocument.childCount != 1 ||
       (![document.rootDocument.children[0].name isEqualToString:kKeyFileRootElementName])) {
        NSLog(@"Does not contain KeyFile root element... not an xml key file");
        return nil;
    }
    
    NSXMLNode *keyFileNode = document.rootDocument.children[0];
    
    if(keyFileNode.childCount < 2) { 
        NSLog(@"Does not contain 2 child elements... not an xml key file");
        return nil;
    }
    
    BOOL version2 = NO;
    
    
    
    NSXMLNode* meta = [keyFileNode.children firstOrDefault:^BOOL(NSXMLNode * _Nonnull obj) {
        return [obj.name isEqualToString:kMetaElementName];
    }];
    
    if ( meta ) {
        NSXMLNode* version = [meta.children firstOrDefault:^BOOL(NSXMLNode * _Nonnull obj) {
            return [obj.name isEqualToString:kVersionElementName];
        }];
        
        if ( version ) {

            version2 = version.stringValue.length && [[version.stringValue substringToIndex:1] isEqualToString:@"2"];
        }
    }

    

    NSXMLNode* keyElement = [keyFileNode.children firstOrDefault:^BOOL(NSXMLNode * _Nonnull obj) {
        return [obj.name isEqualToString:kKeyElementName];
    }];
    
    if ( keyElement ) {
        NSXMLNode* data = [keyElement.children firstOrDefault:^BOOL(NSXMLNode * _Nonnull obj) {
            return [obj.name isEqualToString:kDataElementName];
        }];
        
        if ( data ) {

            
            if (version2) {
                NSString* str = data.stringValue ? data.stringValue : @"";
                NSData* key = str.dataFromHex;
                
                if ( key ) {
                    NSXMLElement* elem = (NSXMLElement*)data;
                    NSXMLNode* expectedHash = [elem.attributes firstOrDefault:^BOOL(NSXMLNode * _Nonnull obj) {
                        return [obj.name isEqualToString:kHashAttributeName];
                    }];
                    
                    

                    NSString* actualHash = key.sha256.hexString;
                    if ( expectedHash && expectedHash.stringValue.length && ![[actualHash substringToIndex:8] isEqualToString:expectedHash.stringValue] ) {
                        NSLog(@"WARNWARN: Hash check failed for V2 Key File");
                        return nil;
                    }

                    return key;
                }
            }
            else {
                NSData* key = [[NSData alloc] initWithBase64EncodedString:data.stringValue options:NSDataBase64DecodingIgnoreUnknownCharacters];
                return key;
            }
        }
    }
    
    return nil;
}

@end
