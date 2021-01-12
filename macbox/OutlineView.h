//
//  OutlineView.h
//  MacBox
//
//  Created by Strongbox on 28/12/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface OutlineView : NSOutlineView

@property (nonatomic, copy, nullable) void (^onDeleteKey)(void);
@property (nonatomic, copy, nullable) void (^onEnterKey)(void);

@end

NS_ASSUME_NONNULL_END
