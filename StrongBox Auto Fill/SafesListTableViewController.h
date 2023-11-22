//
//  SafesListTableViewController.h
//  Strongbox AutoFill
//
//  Created by Mark on 11/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CredentialProviderViewController.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^SelectAutoFillDatabaseCompletion)(BOOL userCancelled, DatabasePreferences* _Nullable database);

@interface SafesListTableViewController : UITableViewController

+ (UINavigationController*)navControllerfromStoryboard:(SelectAutoFillDatabaseCompletion)completion;

@property (nonatomic, copy) SelectAutoFillDatabaseCompletion completion;

@end

NS_ASSUME_NONNULL_END
