//
//  SyncLogEntryTableViewCell.h
//  Strongbox
//
//  Created by Strongbox on 10/08/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SyncOperationState.h"

NS_ASSUME_NONNULL_BEGIN

@interface SyncLogEntryTableViewCell : UITableViewCell

- (void)setState:(SyncOperationState)state log:(NSString*)log timestamp:(NSString*)timestamp;

@end

NS_ASSUME_NONNULL_END
