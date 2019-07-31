//
//  SafesListTableViewController.h
//  Strongbox Auto Fill
//
//  Created by Mark on 11/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <DZNEmptyDataSet/UIScrollView+EmptyDataSet.h>
#import "CredentialProviderViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface SafesListTableViewController : UITableViewController<DZNEmptyDataSetSource, DZNEmptyDataSetDelegate>

@property (nonatomic) CredentialProviderViewController *rootViewController;

@end

NS_ASSUME_NONNULL_END
