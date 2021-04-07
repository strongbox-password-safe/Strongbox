//
//  SafeDetailsView.h
//  StrongBox
//
//  Created by Mark on 09/09/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"
#import "StaticDataTableViewController.h"
#import "YubiKeyHardwareConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseOperations : StaticDataTableViewController

@property (nonatomic) Model *viewModel;

@property (nonatomic, copy) void (^onDatabaseBulkIconUpdate)(NSDictionary<NSUUID *,UIImage *> * _Nullable selectedFavIcons);
@property (nonatomic, copy) void (^onSetMasterCredentials)(NSString* _Nullable password, NSString* _Nullable keyFileBookmark, NSData* _Nullable oneTimeKeyFileData, YubiKeyHardwareConfiguration* _Nullable yubiConfig);

@end

NS_ASSUME_NONNULL_END
