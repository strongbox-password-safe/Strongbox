//
//  KeePassDatabaseWideProperties.h
//  MacBox
//
//  Created by Strongbox on 14/05/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Meta.h"
#import "UnifiedDatabaseMetadata.h"

NS_ASSUME_NONNULL_BEGIN

@interface KeePassDatabaseWideProperties : NSObject

@property NSDictionary<NSUUID*, NSData*> * customIcons;
@property (nullable) Meta* originalMeta;
@property NSDictionary<NSUUID*, NSDate*>* deletedObjects;
@property UnifiedDatabaseMetadata* metadata;

@end

NS_ASSUME_NONNULL_END
