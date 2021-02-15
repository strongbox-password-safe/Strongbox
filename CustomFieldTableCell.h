//
//  CustomFieldTableCell.h
//  Strongbox-iOS
//
//  Created by Mark on 26/03/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const CustomFieldCellHeightChanged;

@interface CustomFieldTableCell : UITableViewCell

@property NSString* key;
@property NSString* value;
@property BOOL concealed;
@property BOOL isHideable;
@property BOOL colorize;

@end

NS_ASSUME_NONNULL_END
