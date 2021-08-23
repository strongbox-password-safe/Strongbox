//
//  DuplicateOptionsViewController.h
//  Strongbox
//
//  Created by Strongbox on 01/08/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "StaticDataTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^DuplicateOptionsCompletionBlock)(BOOL go, BOOL referencePassword, BOOL referenceUsername, BOOL preserveTimestamp, NSString* title, BOOL editAfter);

@interface DuplicateOptionsViewController : StaticDataTableViewController

+ (instancetype)instantiate;

- (void)presentFromViewController:(UIViewController*)viewController;

@property BOOL showFieldReferencingOptions;
@property (copy) DuplicateOptionsCompletionBlock completion;
@property NSString* initialTitle;

@end

NS_ASSUME_NONNULL_END
