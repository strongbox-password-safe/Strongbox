//
//  SelectPredefinedIconController.h
//  Strongbox
//
//  Created by Mark on 25/02/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "NodeIcon.h"

NS_ASSUME_NONNULL_BEGIN

@interface SelectPredefinedIconController : NSWindowController

@property (copy)void (^onSelectedItem)(NodeIcon*_Nullable icon, BOOL showFindFavIcons);

@property BOOL hideSelectFile;
@property BOOL hideFavIconButton;

@property NSArray<NodeIcon*>* customIcons;

@end

NS_ASSUME_NONNULL_END
