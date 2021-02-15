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

@interface SafesListTableViewController : UITableViewController

@property (nonatomic, weak) CredentialProviderViewController *rootViewController;
@property BOOL lastRunGood;

@end

NS_ASSUME_NONNULL_END
