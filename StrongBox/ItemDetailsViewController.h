//
//  ItemDetailsViewController.h
//  test-new-ui
//
//  Created by Mark on 18/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Node.h"
#import "Model.h"

#ifdef IS_APP_EXTENSION
#import "CredentialProviderViewController.h"
#endif

NS_ASSUME_NONNULL_BEGIN

extern NSString *const CellHeightsChangedNotification;

@interface ItemDetailsViewController : UITableViewController

@property BOOL createNewItem;
@property Node* parentGroup;
@property Node*_Nullable item;
@property BOOL readOnly;
@property Model* databaseModel;

@property (nonatomic, copy) void (^onChanged)(void);

#ifdef IS_APP_EXTENSION
@property (nonatomic, strong) CredentialProviderViewController *autoFillRootViewController;
@property (nonatomic, nullable) NSString* autoFillSuggestedTitle;
@property (nonatomic, nullable) NSString* autoFillSuggestedUrl;
#endif

@end

NS_ASSUME_NONNULL_END
