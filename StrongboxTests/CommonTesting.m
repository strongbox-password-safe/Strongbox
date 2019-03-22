//
//  CommonTesting.m
//  StrongboxTests
//
//  Created by Mark on 20/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "CommonTesting.h"
#import "KeePassXmlParserDelegate.h"
#import "KeePassDatabase.h"

@interface CommonTesting ()

@property NSMutableDictionary* testFilesAndKeys;

@end

@implementation CommonTesting


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
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:[xml dataUsingEncoding:NSUTF8StringEncoding]];

    KeePassXmlParserDelegate *parserDelegate;
    if(!key) {
        parserDelegate = [[KeePassXmlParserDelegate alloc] initV3Plaintext];
    }
    else {
        parserDelegate = [[KeePassXmlParserDelegate alloc] initV3WithProtectedStreamId:kInnerStreamSalsa20 key:key];
    }
    
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

@end
