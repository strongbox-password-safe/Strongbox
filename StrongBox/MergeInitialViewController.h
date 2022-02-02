//
//  MergeInitialViewController.h
//  Strongbox
//
//  Created by Mark on 07/12/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DatabasePreferences.h"
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface MergeInitialViewController : UIViewController

@property DatabasePreferences* firstMetadata;
@property (nonatomic, copy) void (^onDone)(BOOL mergeRequested, Model*_Nullable first, Model*_Nullable second);

@end

NS_ASSUME_NONNULL_END
