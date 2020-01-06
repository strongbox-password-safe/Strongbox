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

- (void)close;

@property Node* node;
@property ViewModel* model;
@property BOOL newEntry;
@property BOOL historical;

@property (nullable) dispatch_block_t onClosed;

@end

NS_ASSUME_NONNULL_END
