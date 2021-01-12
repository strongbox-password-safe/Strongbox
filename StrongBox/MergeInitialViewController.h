//
//  MergeInitialViewController.h
//  Strongbox
//
//  Created by Mark on 07/12/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SafeMetaData.h"

NS_ASSUME_NONNULL_BEGIN

@interface MergeInitialViewController : UIViewController

@property SafeMetaData* firstMetadata;
@property (nonatomic, copy) void (^onDone)(void);

@end

NS_ASSUME_NONNULL_END
