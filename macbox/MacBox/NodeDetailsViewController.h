//
//  NodeDetailsViewController.h
//  Strongbox
//
//  Created by Mark on 27/12/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ViewModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface NodeDetailsViewController : NSViewController

@property Node* node;
@property (weak) ViewModel* model;
@property BOOL newEntry;
@property BOOL historical;

@property (nullable) dispatch_block_t onClosed;

- (void)closeWithCompletion:(nullable void (^)(void))completion;

@end

NS_ASSUME_NONNULL_END
