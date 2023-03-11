//
//  SelectPredefinedIconController.h
//  Strongbox
//
//  Created by Mark on 25/02/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "NodeIcon.h"
#import "KeePassIconSet.h"

NS_ASSUME_NONNULL_BEGIN

@interface SelectPredefinedIconController : NSWindowController

@property (copy)void (^onSelectedItem)(NodeIcon*_Nullable icon, BOOL showFindFavIcons);

@property BOOL hideSelectFile;
@property BOOL hideFavIconButton;
@property KeePassIconSet iconSet;

@property NSArray<NodeIcon*>* iconPool;

@end

NS_ASSUME_NONNULL_END
