//
//  MMcGACTextFieldCell.h
//  Strongbox
//
//  Created by Mark on 09/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MMcGACTextFieldCell : NSTextFieldCell

@property (nonatomic, nullable, copy) void (^onImagePasted)(void);

@end

NS_ASSUME_NONNULL_END
