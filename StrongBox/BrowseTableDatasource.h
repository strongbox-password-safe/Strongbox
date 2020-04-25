//
//  BrowseTableDatasource.h
//  Strongbox-iOS
//
//  Created by Mark on 24/04/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Node.h"

NS_ASSUME_NONNULL_BEGIN

@protocol BrowseTableDatasource <NSObject>

@property (readonly) NSUInteger sections;
@property (readonly) BOOL supportsSlideActions;

- (NSUInteger)rowsForSection:(NSUInteger)section;
- (NSString*_Nullable)titleForSection:(NSUInteger)section;
- (UITableViewCell*)cellForRowAtIndexPath:(NSIndexPath*)indexPath;
- (Node*_Nullable)getNodeFromIndexPath:(NSIndexPath*)indexPath;

@end

NS_ASSUME_NONNULL_END
