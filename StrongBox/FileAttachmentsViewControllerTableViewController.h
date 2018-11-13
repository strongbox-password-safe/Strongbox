//
//  FileAttachmentsViewControllerTableViewController.h
//  Strongbox
//
//  Created by Mark on 01/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NodeFileAttachment.h"
#import "DatabaseAttachment.h"
#import <DZNEmptyDataSet/UIScrollView+EmptyDataSet.h>
#import "DatabaseModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface FileAttachmentsViewControllerTableViewController : UITableViewController<DZNEmptyDataSetSource, DZNEmptyDataSetDelegate>

@property DatabaseFormat format;
@property NSArray<NodeFileAttachment*>* nodeAttachments;
@property NSArray<DatabaseAttachment*>* databaseAttachments;
@property (nonatomic, copy) dispatch_block_t onDoneWithChanges;

@end

NS_ASSUME_NONNULL_END
