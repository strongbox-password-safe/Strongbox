//
//  DatabasePreferencesController.h
//  Strongbox-iOS
//
//  Created by Mark on 21/03/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface DatabasePreferencesController : UITableViewController

@property Model* viewModel;
@property (nonatomic, copy) void (^onDatabaseBulkIconUpdate)(NSDictionary<NSUUID *,UIImage *> * _Nullable selectedFavIcons);
@property (nonatomic, copy) void (^onDone)(BOOL showAllAuditIssues);

@end

NS_ASSUME_NONNULL_END
