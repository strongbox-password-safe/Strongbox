//
//  ClickableImageView.h
//  Strongbox
//
//  Created by Mark on 25/02/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface ClickableImageView : NSImageView

@property BOOL clickable;
@property (copy) void (^onClick)(void);
@property BOOL showClickableBorder;

@end

NS_ASSUME_NONNULL_END
