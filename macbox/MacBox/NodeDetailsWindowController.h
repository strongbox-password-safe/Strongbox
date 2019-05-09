//
//  NodeDetailsWindowController.h
//  Strongbox
//
//  Created by Mark on 28/03/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ViewModel.h"
#import "ViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface NodeDetailsWindowController : NSWindowController

+ (instancetype)showNode:(Node*)node model:(ViewModel*)model readOnly:(BOOL)readOnly parentViewController:(ViewController*)parentViewController newEntry:(BOOL)newEntry;

@end

NS_ASSUME_NONNULL_END
