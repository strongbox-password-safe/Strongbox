//
//  DatabaseCellView.h
//  MacBox
//
//  Created by Strongbox on 18/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DatabaseMetadata.h"

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseCellView : NSTableCellView

- (void)setWithDatabase:(DatabaseMetadata*)metadata;
- (void)setWithDatabase:(DatabaseMetadata*)metadata autoFill:(BOOL)autoFill wormholeUnlocked:(BOOL)wormholeUnlocked;

@property (copy)void (^onBeginEditingNickname)(DatabaseCellView* cell);
@property (copy)void (^onEndEditingNickname)(DatabaseCellView* cell);

@end

NS_ASSUME_NONNULL_END
