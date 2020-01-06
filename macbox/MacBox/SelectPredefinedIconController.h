//
//  SelectPredefinedIconController.h
//  Strongbox
//
//  Created by Mark on 25/02/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface SelectPredefinedIconController : NSWindowController

@property (copy)void (^onSelectedItem)(NSNumber* _Nullable index, NSData* _Nullable data, NSUUID* _Nullable existingCustom, BOOL showFindFavIcons);

@property BOOL hideSelectFile;
@property BOOL hideFavIconButton;

@property NSDictionary<NSUUID*, NSData*>* customIcons;

@end

NS_ASSUME_NONNULL_END
