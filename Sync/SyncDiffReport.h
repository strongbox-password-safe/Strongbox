//
//  SyncDiffReport.h
//  Strongbox
//
//  Created by Strongbox on 20/10/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Node.h"

NS_ASSUME_NONNULL_BEGIN

@interface SyncDiffReport : NSObject

@property NSSet<NSUUID*> * theirNewEntries;
@property NSSet<NSUUID*> * theirNewGroups;
@property NSSet<NSUUID*> * theirEditedEntries;
@property NSSet<NSUUID*> * theirEditedGroups;

@end

NS_ASSUME_NONNULL_END
