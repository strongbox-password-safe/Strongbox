//
//  LocalDatabaseIdentifier.h
//  Strongbox
//
//  Created by Mark on 17/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LocalDatabaseIdentifier : NSObject

+ (instancetype)fromJson:(NSString*)json;
- (NSString*)toJson;

@property NSString* filename;
@property BOOL sharedStorage;

@end

NS_ASSUME_NONNULL_END
