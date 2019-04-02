//
//  KeyFileParser.m
//  Strongbox
//
//  Created by Mark on 04/12/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "KeyFileParser.h"
#import "KissXML.h"
#import "Utils.h"

static NSString* const kKeyFileRootElementName = @"KeyFile";
static NSString* const kKeyElementName = @"Key";
static NSString* const kDataElementName = @"Data";

@implementation KeyFileParser

+ (NSData *)getKeyFileDigestFromFileData:(NSData *)data {
    if(!data) {
        return nil;
    }

    // The Key File can be provided in 4 formats:
    
    // 1. XML file with 32-byte key encoded as Base64 string
    
    NSData* xml = [KeyFileParser getXmlKey:data];
    if(xml) {
        return xml;
    }

    // 2. 32 byte binary file - this is the digest directly

    if (data.length == 32) {
        return data;
    }

    // 3. Text file with a 32-byte key encoded as a hex string (64 characters)

    NSData* textHex = [KeyFileParser getHexTextKey:data];
    if(textHex) {
        return textHex;
    }
    
    // 4. Any other file is hashed by sha256, which again produces a 32-byte key.

    return sha256(data);
}

+ (NSData*)getHexTextKey:(NSData*)data {
    if(data.length == 64) {
        NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        
        return [KeyFileParser dataWithHexString:text];
    }

    return nil;
}

+(NSData*)dataWithHexString:(NSString *)hex
{
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
    // <?xml version="1.0" encoding="utf-8"?>
    // <KeyFile>
    //    <Meta>
    //        <Version>1.00</Version>
    //    </Meta>
    //    <Key>
    //        <Data>qoqpuidtJAbJZI8XL3DxGqQkxEo6HZbxnhCStAZIYsE=</Data>
    //    </Key>
    // </KeyFile>
    
    NSError *error;
    NSXMLDocument *document = [[NSXMLDocument alloc] initWithData:data options:kNilOptions error:&error];
    
    if(!document || error != nil) {
        //NSLog(@"Error opening Key File: %@", error);
        return nil;
    }
    
    if(!document.rootDocument || document.rootDocument.childCount != 1 ||
       (![document.rootDocument.children[0].name isEqualToString:kKeyFileRootElementName])) {
        NSLog(@"Does not contain KeyFile root element... not an xml key file");
        return nil;
    }
    
    NSXMLNode *keyFileNode = document.rootDocument.children[0];
    
    if(keyFileNode.childCount < 2) { // Must contain Meta and Key elements
        NSLog(@"Does not contain 2 child elements... not an xml key file");
        return nil;
    }
    
    for (NSXMLNode* node in keyFileNode.children) {
        if([node.name isEqualToString:kKeyElementName]) {
            for (NSXMLNode* childNode in node.children) {
                if([childNode.name isEqualToString:kDataElementName]) {
                    //NSLog(@"%@", childNode.stringValue);
                    
                    NSData* key = [[NSData alloc] initWithBase64EncodedString:childNode.stringValue options:kNilOptions];
                    
                    return key; 
                }
            }
        }
    }
    
    return nil;
}

@end
