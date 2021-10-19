//
//  MasterPasswordExplanationViewController.h
//  Strongbox
//
//  Created by Strongbox on 08/10/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SafeMetaData.h"

NS_ASSUME_NONNULL_BEGIN

@interface MasterPasswordExplanationViewController : UIViewController

@property NSString* name;
@property (nonatomic, copy) void (^onDone)(BOOL addExisting, SafeMetaData* _Nullable databaseToOpen);

@end

NS_ASSUME_NONNULL_END
