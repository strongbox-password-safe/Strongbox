//
//  KeyFilesTableViewController.h
//  Strongbox
//
//  Created by Mark on 28/05/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KeyFilesTableViewController : UITableViewController

@property (nonatomic, copy) void (^onDone)(BOOL success, NSURL* _Nullable url, NSData* _Nullable oneTimeData);
@property NSURL* selectedUrl;

@end

NS_ASSUME_NONNULL_END
