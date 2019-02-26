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

@property (copy)void (^onSelectedItem)(NSNumber* _Nullable index, NSData* _Nullable data);
@property BOOL hideSelectFile;

@end

NS_ASSUME_NONNULL_END
