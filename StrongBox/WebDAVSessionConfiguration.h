//
//  WebDAVSessionConfiguration.h
//  Strongbox
//
//  Created by Mark on 11/12/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WebDAVSessionConfiguration : NSObject

@property NSString* identifier;
@property (nullable) NSString* name;

@property NSURL* host;
@property NSString* username;
@property NSString* password;
@property BOOL allowUntrustedCertificate;

- (NSDictionary*)serializationDictionary;
+ (instancetype _Nullable)fromSerializationDictionary:(NSDictionary*)dictionary;

-(NSString*)getKeyChainKey:(NSString*)propertyName;

- (void)clearKeychainItems;

- (BOOL)isTheSameConnection:(WebDAVSessionConfiguration*)other;
- (BOOL)isNetworkingFieldsAreSame:(WebDAVSessionConfiguration *)other;

@end

NS_ASSUME_NONNULL_END
