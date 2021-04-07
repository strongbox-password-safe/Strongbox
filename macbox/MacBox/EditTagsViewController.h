//
//  EditTagsViewController.h
//  MacBox
//
//  Created by Strongbox on 07/04/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface EditTagsViewController : NSViewController

@property (nonatomic, copy) void (^onRemove)(NSString* tag);
@property (nonatomic, copy) void (^onAdd)(NSString* tag);
@property NSArray<NSString*> *items;

@end

NS_ASSUME_NONNULL_END
