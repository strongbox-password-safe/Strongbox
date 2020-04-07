//
//  SafeDetailsView.h
//  StrongBox
//
//  Created by Mark on 09/09/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"
#import "StaticDataTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseOperations : StaticDataTableViewController

@property (nonatomic) Model *viewModel;

@property (nonatomic, copy) void (^onDatabaseBulkIconUpdate)(NSDictionary<NSUUID *,UIImage *> * _Nullable selectedFavIcons);

@end

NS_ASSUME_NONNULL_END
