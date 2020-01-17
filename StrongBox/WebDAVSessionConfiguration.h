//
//  WebDAVSessionConfiguration.h
//  Strongbox
//
//  Created by Mark on 11/12/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WebDAVSessionConfiguration : NSObject

@property NSURL* host;
@property NSString* username;
@property NSString* password;
@property BOOL allowUntrustedCertificate;

- (NSDictionary*)serializationDictionary;
+ (instancetype)fromSerializationDictionary:(NSDictionary*)dictionary;

-(NSString*)getKeyChainKey:(NSString*)propertyName;

@end

NS_ASSUME_NONNULL_END
