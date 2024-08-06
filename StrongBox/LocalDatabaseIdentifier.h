//
//  LocalDatabaseIdentifier.h
//  Strongbox
//
//  Created by Mark on 17/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SBLog.h"

NS_ASSUME_NONNULL_BEGIN

@interface LocalDatabaseIdentifier : NSObject

+ (instancetype _Nullable)fromJson:(NSString*)json;
- (NSString* _Nullable)toJson;

@property NSString* filename;
@property BOOL sharedStorage;

@end

NS_ASSUME_NONNULL_END
