//
//  IconsCollectionViewController.h
//  Strongbox
//
//  Created by Mark on 22/02/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface IconsCollectionViewController : UIViewController

@property (nonatomic, copy) void (^onDone)(BOOL response, NSInteger selectedIndex, NSUUID*_Nullable selectedCustomIconId);
@property NSDictionary<NSUUID*, NSData*>* customIcons;

@end

NS_ASSUME_NONNULL_END
