//
//  SFTPProviderData.h
//  Strongbox
//
//  Created by Mark on 11/12/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SFTPProviderData : NSObject

@property NSString* filePath;
@property NSString* connectionIdentifier;

+ (instancetype)fromSerializationDictionary:(NSDictionary*)dictionary;
- (NSDictionary*)serializationDictionary;

@end

NS_ASSUME_NONNULL_END
