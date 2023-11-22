//
//  FavIconDownloader.h
//  Strongbox
//
//  Created by Mark on 17/12/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "ViewModel.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^FavIconBulkDoneBlock)(BOOL go, NSDictionary<NSUUID*, NodeIcon*> * _Nullable selectedFavIcons);

@interface FavIconDownloader : NSViewController

@property NSArray<Node*> *nodes;
@property FavIconBulkDoneBlock onDone;
@property ViewModel* viewModel;

+ (instancetype)newVC;

@end

NS_ASSUME_NONNULL_END
