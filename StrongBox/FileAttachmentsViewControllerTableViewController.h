//
//  FileAttachmentsViewControllerTableViewController.h
//  Strongbox
//
//  Created by Mark on 01/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DatabaseModel.h"
#import "UiAttachment.h"

NS_ASSUME_NONNULL_BEGIN

@interface FileAttachmentsViewControllerTableViewController : UITableViewController

@property DatabaseFormat format;
@property NSArray<UiAttachment*>* attachments;
@property (nonatomic, copy) dispatch_block_t onDoneWithChanges;
@property BOOL readOnly;

@end

NS_ASSUME_NONNULL_END
