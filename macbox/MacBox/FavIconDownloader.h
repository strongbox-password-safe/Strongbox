//
//  FavIconDownloader.h
//  Strongbox
//
//  Created by Mark on 17/12/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "ViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface FavIconDownloader : ViewController

typedef void (^FavIconBulkDoneBlock)(BOOL go, NSDictionary<NSUUID*, NSImage*> * _Nullable selectedFavIcons);



+ (instancetype)showUi:(NSViewController*)parentVc nodes:(NSArray<Node*>*)nodes viewModel:(ViewModel*)viewModel onDone:(FavIconBulkDoneBlock)onDone;

@end

NS_ASSUME_NONNULL_END
