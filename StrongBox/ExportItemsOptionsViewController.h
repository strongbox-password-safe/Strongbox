//
//  ExportOptionsViewController.h
//  Strongbox
//
//  Created by Strongbox on 29/07/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "StaticDataTableViewController.h"
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^ExportItemsCompletionBlock)(BOOL makeBrandNewCopy, BOOL preserveTimestamps);

@interface ExportItemsOptionsViewController : StaticDataTableViewController

@property NSArray<Node*>* items;
@property NSSet<NSUUID*> *itemsIntersection;
@property Model* destinationModel;
@property (copy) ExportItemsCompletionBlock completion;

@end

NS_ASSUME_NONNULL_END
