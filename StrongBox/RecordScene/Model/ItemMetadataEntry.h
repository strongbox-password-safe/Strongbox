//
//  ItemMetadataEntry.h
//  Strongbox-iOS
//
//  Created by Mark on 27/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ItemMetadataEntry : NSObject

+ (instancetype)entryWithKey:(NSString*)key value:(NSString*)value copyable:(BOOL)copyable;
- (instancetype)init NS_UNAVAILABLE;

@property NSString* key;
@property NSString* value;
@property BOOL copyable;

@end

NS_ASSUME_NONNULL_END
