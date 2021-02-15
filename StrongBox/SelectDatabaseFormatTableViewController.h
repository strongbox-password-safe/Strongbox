//
//  NewSafeFormatController.h
//  Strongbox-iOS
//
//  Created by Mark on 06/11/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AbstractDatabaseFormatAdaptor.h"

NS_ASSUME_NONNULL_BEGIN

@interface SelectDatabaseFormatTableViewController : UITableViewController

@property DatabaseFormat existingFormat;
@property (nonatomic, copy) void (^onSelectedFormat)(DatabaseFormat format);

@end

NS_ASSUME_NONNULL_END
