//
//  QuickTypeRecordIdentifier.h
//  Strongbox
//
//  Created by Mark on 31/03/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QuickTypeRecordIdentifier : NSObject

+ (instancetype)identifierWithDatabaseId:(NSString*)databaseId nodeId:(NSString*)nodeId;

+ (instancetype)fromJson:(NSString*)json;
- (NSString*)toJson;

@property NSString* databaseId;
@property NSString* nodeId;

@end

NS_ASSUME_NONNULL_END
