//
//  FavIconResultTableCellView.h
//  Strongbox
//
//  Created by Mark on 21/12/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ClickableImageView.h"

NS_ASSUME_NONNULL_BEGIN

@interface FavIconResultTableCellView : NSTableCellView

@property (weak) IBOutlet NSImageView *icon;
@property (weak) IBOutlet NSTextField *title;
@property (weak) IBOutlet NSTextField *subTitle;

@property BOOL checkable;
@property BOOL checked;
@property BOOL showIconChooseButton;

@property (copy, nullable) void (^onClickChooseIcon)(void);
@property (copy, nullable) void (^onCheckChanged)(void);

@end

NS_ASSUME_NONNULL_END
