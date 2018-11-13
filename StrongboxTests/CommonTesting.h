//
//  CommonTesting.h
//  StrongboxTests
//
//  Created by Mark on 20/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RootXmlDomainObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface CommonTesting : NSObject

+ (NSDictionary<NSString*, NSString*>*)testKdbx4FilesAndPasswords;
+ (NSDictionary<NSString*, NSString*>*)testKdbxFilesAndPasswords;
+ (NSDictionary<NSString*, NSString*>*)testXmlFilesAndKeys;
+ (NSDictionary<NSString*, NSString*>*)testKdbFilesAndPasswords;

+ (NSData*)getDataFromBundleFile:(NSString*)fileName ofType:(NSString*)ofType;
+ (NSString*)getXmlFromBundleFile:(NSString*)fileName;
+ (RootXmlDomainObject*)parseKeePassXml:(NSString*)xml;
+ (RootXmlDomainObject*)parseKeePassXmlSalsa20:(NSString*)xml b64key:(nullable NSString*)b64key;
+ (RootXmlDomainObject*)parseKeePassXmlSalsa20:(NSString*)xml key:(nullable NSData*)key;

@end

NS_ASSUME_NONNULL_END
