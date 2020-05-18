//
//  KeePassDatabaseWideProperties.h
//  MacBox
//
//  Created by Strongbox on 14/05/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DeletedItem.h"
#import "Meta.h"

NS_ASSUME_NONNULL_BEGIN

@interface KeePassDatabaseWideProperties : NSObject

@property NSDictionary<NSUUID*, NSData*> * customIcons;
@property Meta* originalMeta;
@property NSArray<DeletedItem*>* deletedObjects;

@end

NS_ASSUME_NONNULL_END
