//
//  KeePassDatabaseWideProperties.h
//  MacBox
//
//  Created by Strongbox on 14/05/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UnifiedDatabaseMetadata.h"

NS_ASSUME_NONNULL_BEGIN

@interface KeePassDatabaseWideProperties : NSObject

@property NSDictionary<NSUUID*, NSDate*>* deletedObjects;
@property UnifiedDatabaseMetadata* metadata;

@end

NS_ASSUME_NONNULL_END
