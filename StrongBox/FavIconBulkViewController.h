//
//  FavIconBulkViewController.h
//  Strongbox
//
//  Created by Mark on 27/11/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface FavIconBulkViewController : UIViewController

typedef void (^FavIconBulkDoneBlock)(BOOL go, NSDictionary<NSUUID*, UIImage*> * _Nullable selectedFavIcons);



+ (void)presentModal:(UIViewController*)presentingVc node:node urlOverride:(NSString*)urlOverride onDone:(FavIconBulkDoneBlock)onDone;

+ (void)presentModal:(UIViewController*)presentingVc nodes:(NSArray<Node*>*)nodes onDone:(FavIconBulkDoneBlock)onDone;

@end

NS_ASSUME_NONNULL_END
