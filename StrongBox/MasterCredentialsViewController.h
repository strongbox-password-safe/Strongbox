//
//  MasterCredentialsViewController.h
//  Strongbox
//
//  Created by Mark on 28/05/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface MasterCredentialsViewController : UIViewController

@property SafeMetaData* database;

@property (nonatomic, copy) void (^onDone)(BOOL success, NSString* _Nullable password, NSData* _Nullable keyFileData, BOOL openOffline);

@end

NS_ASSUME_NONNULL_END
