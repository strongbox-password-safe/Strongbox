//
//  FavIconBulkViewController.h
//  Strongbox
//
//  Created by Mark on 27/11/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface FavIconBulkViewController : UIViewController

typedef void (^FavIconBulkDoneBlock)(BOOL go, NSDictionary<NSUUID*, NodeIcon*> * _Nullable selectedFavIcons);



+ (void)presentModal:(UIViewController*)presentingVc model:(Model*)model node:node urlOverride:(NSString*)urlOverride onDone:(FavIconBulkDoneBlock)onDone;

+ (void)presentModal:(UIViewController*)presentingVc model:(Model*)model nodes:(NSArray<Node*>*)nodes onDone:(FavIconBulkDoneBlock)onDone;

@end

NS_ASSUME_NONNULL_END
