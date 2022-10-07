//
//  DatabasePreferencesController.h
//  Strongbox-iOS
//
//  Created by Mark on 21/03/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"
#import "StaticDataTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface DatabasePreferencesController : StaticDataTableViewController

@property Model* viewModel;

@property (nonatomic, copy) void (^onDatabaseBulkIconUpdate)(NSDictionary<NSUUID *,UIImage *> * _Nullable selectedFavIcons);

@property (nonatomic, copy) void (^onSetMasterCredentials)(NSString* _Nullable password, NSString* _Nullable keyFileBookmark, NSString* _Nullable keyFileFileName, NSData* _Nullable oneTimeKeyFileData, YubiKeyHardwareConfiguration* _Nullable yubiConfig);

@property (nonatomic, copy) void (^onDone)(BOOL showAllAuditIssues, __weak UIViewController* viewControllerToDismiss);

@property (nonatomic, copy) void (^updateDatabase)(void); 

@end

NS_ASSUME_NONNULL_END
