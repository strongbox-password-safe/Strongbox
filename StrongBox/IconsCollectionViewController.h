//
//  IconsCollectionViewController.h
//  Strongbox
//
//  Created by Mark on 22/02/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DatabasePreferences.h"
#import "NodeIcon.h"

NS_ASSUME_NONNULL_BEGIN

@interface IconsCollectionViewController : UIViewController

@property (nonatomic, copy) void (^onDone)(BOOL response, NodeIcon*_Nullable icon);

@property NSDictionary<NSUUID*, NodeIcon*>* iconPool;
@property KeePassIconSet predefinedKeePassIconSet;

@end

NS_ASSUME_NONNULL_END
