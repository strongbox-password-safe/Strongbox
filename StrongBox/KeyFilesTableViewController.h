//
//  KeyFilesTableViewController.h
//  Strongbox
//
//  Created by Mark on 28/05/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KeyFilesTableViewController : UITableViewController

@property (nonatomic, copy) void (^onDone)(BOOL success, NSURL* _Nullable url, NSData* _Nullable oneTimeData);
@property (nullable) NSURL* selectedUrl;
@property BOOL manageMode;

@end

NS_ASSUME_NONNULL_END
