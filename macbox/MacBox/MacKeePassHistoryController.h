//
//  KeePassHistoryController.h
//  Strongbox
//
//  Created by Mark on 11/03/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ViewModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface MacKeePassHistoryController : NSWindowController

@property (copy)void (^onRestoreHistoryItem)(Node* node);
@property (copy)void (^onDeleteHistoryItem)(Node* node);

@property NSArray<Node*>* history;
@property ViewModel* model;

@end

NS_ASSUME_NONNULL_END
