//
//  MMcGACTextField.h
//  Strongbox
//
//  Created by Mark on 09/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MMcGACTextField : NSTextField

@property NSArray<NSString*>* completions;
@property BOOL completionEnabled;

@property (nonatomic, copy) void (^onBeginEditing)(void);
@property (nonatomic, copy) void (^onEndEditing)(void);
@property (nonatomic, nullable, copy) void (^onTextDidChange)(void);
@property (nonatomic, nullable, copy) void (^onImagePasted)(void);

@end

NS_ASSUME_NONNULL_END
