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
#import "BookmarksHelper.h"
#import "Utils.h"
#import "FileManager.h"

#import "Sha256PassThroughOutputStream.h"
#import "StreamUtils.h"
#import <CommonCrypto/CommonCrypto.h>

#if TARGET_OS_IPHONE
#import "KissXML.h" 
#endif

static NSString* const kKeyFileRootElementName = @"KeyFile";
static NSString* const kKeyElementName = @"Key";
static NSString* const kDataElementName = @"Data";
static NSString* const kMetaElementName = @"Meta";
static NSString* const kVersionElementName = @"Version";
static NSString* const kHashAttributeName = @"Hash";

static const NSUInteger kStreamReadThreshold = 16 * 1024;

@implementation KeyFileParser

+ (NSData *)getDigest:(NSInputStream*)inStream
         streamLength:(unsigned long long)streamLength
          checkForXml:(BOOL)checkForXml {
    if ( inStream == nil ) {
        return nil;
    }
    
    if ( streamLength > kStreamReadThreshold ) {
        NSLog(@"INFO: Large Key File, will stream the digest and skip XML, Hex etc checks. Pure SHA256");
             
        [inStream open];
        
        CC_SHA256_CTX *sha256context = malloc(sizeof(CC_SHA256_CTX));
        CC_SHA256_Init(sha256context);
        
        const NSUInteger kChunkSize = 4 * 1024;
        uint8_t buffer[kChunkSize];

        NSInteger len;
        while ( ( len = [inStream read:buffer maxLength:kChunkSize] ) > 0 ) {
            CC_SHA256_Update(sha256context, buffer, (CC_LONG)len);
        }
        
        if ( len != 0 ) {
            NSLog(@"WARNWARN: Could not read key file stream: [%ld] - [%@]", (long)len, inStream.streamError);
            [inStream close];
            free(sha256context);
            return nil;
        }
        [inStream close];

        NSMutableData* foo = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
        CC_SHA256_Final(foo.mutableBytes, sha256context);
        
        free(sha256context);
        
        return foo.copy;
    }
    
    NSData* data = [NSData dataWithContentsOfStream:inStream];
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
    
    

    NSData* ret = data.sha256;
    
    return ret;
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



+ (NSData *)getNonePerformantKeyFileDigest:(NSData *)data checkForXml:(BOOL)checkForXml {
    return [self getDigestFromSources:nil
                      keyFileFileName:nil
                   onceOffKeyFileData:data
                               format:checkForXml ? kKeePass4 : kKeePass1 error:nil];
}

+ (NSData *)getDigestFromBookmark:(NSString *)keyFileBookmark
                  keyFileFileName:(NSString*)keyFileFileName
                           format:(DatabaseFormat)format
                            error:(NSError **)error {
    return [KeyFileParser getDigestFromSources:keyFileBookmark
                               keyFileFileName:nil
                            onceOffKeyFileData:nil
                                        format:format
                                         error:error];
}

static NSData * _Nullable getByUrl(NSError *__autoreleasing *error, DatabaseFormat format, NSURL *keyFileUrl) {
    NSError* attrError;
    NSDictionary* attributes = [NSFileManager.defaultManager attributesOfItemAtPath:keyFileUrl.path error:&attrError];
    
    if ( !attributes || attrError ) {
        if ( error ) {
            *error = attrError;
        }
        
        NSLog(@"WARNWARN: Could not read Key File URL File Size.");
        
        return nil;
    }
    
    unsigned long long fileSize = attributes.fileSize;
    
    BOOL securitySucceeded = [keyFileUrl startAccessingSecurityScopedResource];
    NSInputStream* inStream = [NSInputStream inputStreamWithURL:keyFileUrl];
    
    NSData* ret = [KeyFileParser getDigest:inStream streamLength:fileSize checkForXml:format != kKeePass1];
    
    if ( securitySucceeded ) {
        [keyFileUrl stopAccessingSecurityScopedResource];
    }
    
    return ret;
}

+ (NSData * _Nullable)getByBookmark:(NSError **)error
                             format:(DatabaseFormat)format
                    keyFileBookmark:(NSString *)keyFileBookmark {
    NSString* updated;
    NSURL* keyFileUrl = [BookmarksHelper getUrlFromBookmark:keyFileBookmark
                                                   readOnly:YES
                                            updatedBookmark:&updated
                                                      error:error];
    
    if ( keyFileUrl ) {
        return getByUrl(error, format, keyFileUrl);
    }
    else {
        if ( error ) {
            *error = [Utils createNSError:@"Could not read Key File Bookmark" errorCode:-123456];
        }
        
        NSLog(@"WARNWARN: Could not read Key File Bookmark.");
        return nil;
    }
}

+ (NSData *)getDigestFromSources:(NSString *)keyFileBookmark
                 keyFileFileName:(NSString*)keyFileFileName
              onceOffKeyFileData:(NSData *)onceOffKeyFileData
                          format:(DatabaseFormat)format
                           error:(NSError *__autoreleasing  _Nullable *)error {
    if ( !keyFileBookmark && !onceOffKeyFileData && !keyFileFileName ) {
        NSLog(@"WARNWARN: No Sources is nil");
        
        if ( error ) {
            *error = [Utils createNSError:@"Could not read Key File from NO sources" errorCode:-123456];
        }
        
        return nil;
    }
        
    if ( keyFileBookmark ) {
        NSData* bookmarkData = [KeyFileParser getByBookmark:error format:format keyFileBookmark:keyFileBookmark];
        
        if ( bookmarkData ) {
            return bookmarkData;
        }
    }
    
#if TARGET_OS_IPHONE 
    if ( keyFileFileName ) {
        NSURL* localGroupFile = [FileManager.sharedInstance.keyFilesDirectory URLByAppendingPathComponent:keyFileFileName];
        return getByUrl(error, format, localGroupFile);
    }
#endif

    if ( onceOffKeyFileData ) {
        NSInputStream* inStream = [NSInputStream inputStreamWithData:onceOffKeyFileData];
        
        return [KeyFileParser getDigest:inStream
                           streamLength:onceOffKeyFileData.length
                            checkForXml:format != kKeePass1];
    }

    return nil;
}

@end
