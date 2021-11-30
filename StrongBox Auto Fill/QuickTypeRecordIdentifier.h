//
//  QuickTypeRecordIdentifier.h
//  Strongbox
//
//  Created by Mark on 31/03/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QuickTypeRecordIdentifier : NSObject

+ (instancetype)identifierWithDatabaseId:(NSString*)databaseId nodeId:(NSString*)nodeId fieldKey:(NSString* _Nullable)fieldKey;

+ (instancetype _Nullable)fromJson:(NSString*)json;
- (NSString* _Nullable)toJson;

@property NSString* databaseId;
@property NSString* nodeId;
@property (nullable) NSString* fieldKey;

@end

NS_ASSUME_NONNULL_END
