//
//  SelectStorageProviderController.h
//  StrongBox
//
//  Created by Mark on 08/09/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AbstractDatabaseFormatAdaptor.h"
#import "SelectedStorageParameters.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^SelectStorageCompletion)(SelectedStorageParameters *params);

@interface SelectStorageProviderController : UITableViewController

+ (UINavigationController*)navControllerFromStoryboard;

@property (nonatomic) BOOL existing;
@property (nonatomic, copy) SelectStorageCompletion onDone;

@end

NS_ASSUME_NONNULL_END
