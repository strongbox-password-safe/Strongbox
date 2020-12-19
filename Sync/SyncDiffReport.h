//
//  SyncDiffReport.h
//  Strongbox
//
//  Created by Strongbox on 20/10/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Node.h"
#import "Pair.h"

NS_ASSUME_NONNULL_BEGIN

@interface SyncDiffReport : NSObject

@property NSArray<Node*>* onlyInTheirs;
@property NSArray<Pair<Node*, Node*>*>* differentFromOurs;

@property NSArray<NSUUID*>* changes;

@end

NS_ASSUME_NONNULL_END
