//
//  CommonTesting.m
//  StrongboxTests
//
//  Created by Mark on 20/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "CommonTesting.h"
#import "KeePassDatabase.h"
#import "XmlSerializer.h"
#import "XmlToDictionaryParser.h"
#import "KdbxSerializationCommon.h"

@interface CommonTesting ()

@property NSMutableDictionary* testFilesAndKeys;

@end

@implementation CommonTesting

NSString* getXml(id<XmlParsingDomainObject> obj, BOOL v4) {
    return getXml2(obj, v4, kInnerStreamPlainText, nil);
}

NSString* getXml2(id<XmlParsingDomainObject> obj, BOOL v4, uint32_t streamId, NSData* key) {
    XmlSerializer *s = [[XmlSerializer alloc] initWithProtectedStreamId:streamId key:key v4Format:v4 prettyPrint:YES];
    
    [s beginDocument];
    if([obj writeXml:s]) {
        return s.xml;
    }
    [s endDocument];
    
    return nil;
}

BOOL compareOriginalAndRegenerated(id<XmlParsingDomainObject> origRootGroup, id<XmlParsingDomainObject> regeneratedRootGroup, BOOL v4) {
    NSString *originalXml = getXml(origRootGroup, v4);
    NSLog(@"%@", originalXml);
    
    NSLog(@"============================================================================================================================");
    
    NSString *regeneratedXml = getXml(regeneratedRootGroup, v4);
    NSLog(@"%@", regeneratedXml);

    return compareOriginalAndRegeneratedXml(originalXml, regeneratedXml);
}

BOOL compareOriginalAndRegeneratedXml(NSString* xml1, NSString* xml2) {
    XmlComparisonElement* d1 = dictionaryFromXml(xml1);
    XmlComparisonElement* d2 = dictionaryFromXml(xml2);

    return [d1 isEqual:d2];
}

XmlComparisonElement* dictionaryFromXml(NSString* xml) {
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:[xml dataUsingEncoding:NSUTF8StringEncoding]];
    
    XmlToDictionaryParser *parserDelegate = [[XmlToDictionaryParser alloc] init];

    [parser setDelegate:parserDelegate];
    [parser parse];
    
    NSError* err = [parser parserError];
    
    if(err)
    {
        NSLog(@"%@", err);
        return nil;
    }
    
    return parserDelegate.rootElement;
}

+ (NSDictionary<NSString*, NSString*>*)testKdbFilesAndPasswords {
    static NSDictionary<NSString*, NSString*> *fooDict = nil;
    if (fooDict == nil) {
        fooDict = [NSMutableDictionary dictionary];
        
        [fooDict setValue:@"a" forKey:@"Database-1"];
        [fooDict setValue:@"a" forKey:@"Database-twofish"];
    }
    return fooDict;
}

+ (NSDictionary<NSString*, NSString*>*)testKdbx4FilesAndPasswords {
    static NSDictionary<NSString*, NSString*> *fooDict = nil;
    if (fooDict == nil) {
        fooDict = [NSMutableDictionary dictionary];
        
        [fooDict setValue:@"a" forKey:@"basic"];
        [fooDict setValue:@"a" forKey:@"Database-Aes-Argon2NonDefault"];
        [fooDict setValue:@"a" forKey:@"twofish-argon-2"];
        [fooDict setValue:@"a" forKey:@"custom-icon-4"];
        [fooDict setValue:@"a" forKey:@"db-4-nocompression"];
    }
    
    return fooDict;
}

+ (NSDictionary<NSString*, NSString*>*)testKdbxFilesAndPasswords {
    static NSDictionary<NSString*, NSString*> *fooDict = nil;
    if (fooDict == nil) {
        fooDict = [NSMutableDictionary dictionary];
  
        [fooDict setValue:@"a" forKey:@"generic"];
        [fooDict setValue:@"a" forKey:@"generic-non-gzipped"];
        [fooDict setValue:@"a" forKey:@"Database"];
        [fooDict setValue:@"a" forKey:@"a"];
        [fooDict setValue:@"a" forKey:@"Database-ChCha20-AesKdf"];
        [fooDict setValue:@"a" forKey:@"custom-icon"];
    }
    return fooDict;
}

+ (NSDictionary<NSString*, NSString*>*)testXmlFilesAndKeys {
    static NSDictionary<NSString*, NSString*> *fooDict = nil;
    if (fooDict == nil) {
        fooDict = [NSMutableDictionary dictionary];
        
        [fooDict setValue:@"" forKey:@"minimal"];
        [fooDict setValue:@"" forKey:@"empty-meta"];
        [fooDict setValue:@"" forKey:@"empty-root"];
        [fooDict setValue:@"" forKey:@"empty-root-group"];
        [fooDict setValue:@"" forKey:@"empty-entry"];
        [fooDict setValue:@"" forKey:@"funky"];
        
        [fooDict setValue:@"ztCAmxaRzv/Q/ws53V4wLACfqfJtDELuEa0lR0lK1UA=" forKey:@"keypass-database-with-binary"];
        [fooDict setValue:@"wkt/eqeeT/Ov2p/DM2R16kiM9+Mye52sX5ykoxDMJKQ=" forKey:@"ladder"];
        [fooDict setValue:@"VId5gvqpc1umKBTk16bND/3VGKotVVOTygiw6nGTBYI=" forKey:@"password-five-entries-ladder"];
        [fooDict setValue:@"JvrWpyQom2y63klo6iNBsIIjnt/dRKV2rbu7VRaX+cw=" forKey:@"password-ladder"];
        [fooDict setValue:@"N0gYzFpyRtD8VC/FjMTUN/ehg8tDYydOMWcLWe3rdJI=" forKey:@"password-two-entries-ladder"];
        [fooDict setValue:@"2+0LT4H8KD86L76Umi+eu2T0AM0Dr7/d+oFbFTlLgxk=" forKey:@"password-three-entries-ladder"];
        [fooDict setValue:@"wkt/eqeeT/Ov2p/DM2R16kiM9+Mye52sX5ykoxDMJKQ=" forKey:@"ladder-single-entry"];
    }
    return fooDict;
}

+ (NSData*)getDataFromBundleFile:(NSString*)fileName ofType:(NSString*)ofType {
    NSBundle *bundle = [NSBundle bundleForClass:[CommonTesting class]];
    NSString *path = [bundle pathForResource:fileName ofType:ofType];
    return [NSData dataWithContentsOfFile:path];
}

+ (NSString*)getXmlFromBundleFile:(NSString*)fileName {
    NSBundle *bundle = [NSBundle bundleForClass:[CommonTesting class]];
    if(!bundle) {
        return nil;
    }
    
    NSString *path = [bundle pathForResource:fileName ofType:@"xml"];
    if(!path.length) {
        return nil;
    }
    
    NSString *xml = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:path] encoding:NSUTF8StringEncoding];
    
    return xml;
}

+ (RootXmlDomainObject*)parseKeePassXml:(NSString*)xml {
    return [CommonTesting parseKeePassXmlSalsa20:xml key:nil];
}

+ (RootXmlDomainObject*)parseKeePassXmlSalsa20:(NSString*)xml b64key:(NSString*)b64key {
    NSData *key = b64key.length ? [[NSData alloc] initWithBase64EncodedString:b64key options:NSDataBase64DecodingIgnoreUnknownCharacters] : nil;
    
    return [self parseKeePassXmlSalsa20:xml key:key];
}

+ (RootXmlDomainObject*)parseKeePassXmlSalsa20:(NSString*)xml key:(NSData*)key {
    NSData* d = [xml dataUsingEncoding:NSUTF8StringEncoding];
    
    RootXmlDomainObject* xmlObject;
    if(!key) {
        xmlObject = [CommonTesting parseXml:kInnerStreamPlainText key:nil data:d context:XmlProcessingContext.standardV3Context];
    }
    else {
        xmlObject = [CommonTesting parseXml:kInnerStreamSalsa20 key:key data:d context:XmlProcessingContext.standardV3Context];
    }
    
    return xmlObject;
}

+ (RootXmlDomainObject*)parseXml:(uint8_t)streamId
                             key:(NSData*_Nullable)key
                            data:(NSData*)data
                         context:(XmlProcessingContext*)context {
    NSInputStream* str1 = [NSInputStream inputStreamWithData:data];
    [str1 open];
    
    NSError* error;
    RootXmlDomainObject* ret = parseXml(streamId, key, context, str1, nil, &error);
    
    [str1 close];
    
    if(error) {
        NSLog(@"%@", error);
        return nil;
    }
    
    return ret;
}

@end
