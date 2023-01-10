//
//  OpenSafeView.h
//  StrongBox
//
//  Created by Mark McGuill on 06/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface BrowseSafeView : UITableViewController

+ (instancetype)fromStoryboard:(BrowseViewType)viewType model:(Model*)model;

@property (strong, nonnull) Model *viewModel;
@property (nullable) NSUUID *currentGroupId; 
@property (nullable) NSString* currentTag; 
@property BrowseViewType viewType;

@end

NS_ASSUME_NONNULL_END
