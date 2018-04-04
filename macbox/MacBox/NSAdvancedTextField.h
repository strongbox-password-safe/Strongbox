//
//  NSAdvancedTextField.h
//  Strongbox
//
//  Created by Mark on 19/09/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSAdvancedTextField : NSTextField

@property (nonatomic, strong) void (^multipleClickHandler)(NSInteger clickCount);

@end
