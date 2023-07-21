//
//  EncryptionPreferencesViewController.h
//  Strongbox
//
//  Created by Strongbox on 10/09/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "StaticDataTableViewController.h"
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface EncryptionPreferencesViewController : StaticDataTableViewController

+ (UINavigationController*)fromStoryboard;

@property Model* model;
@property (nonatomic, copy) void (^onChangedDatabaseEncryptionSettings)(void);

@end

NS_ASSUME_NONNULL_END
