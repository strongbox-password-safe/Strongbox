//
//  CreateCredentialTableViewController.h
//  Strongbox
//
//  Created by Mark on 11/02/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"
#import "CredentialProviderViewController.h"

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(12.0))
@interface CreateCredentialTableViewController : UITableViewController

@property (nonatomic) Model *viewModel;
@property (nonatomic, strong) CredentialProviderViewController *rootViewController;
@property (nonatomic) NSString* suggestedTitle;
@property (nonatomic) NSString* suggestedUrl;

@end

NS_ASSUME_NONNULL_END
