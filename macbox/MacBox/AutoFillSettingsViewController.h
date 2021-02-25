//
//  AutoFillSettingsViewController.h
//  Strongbox
//
//  Created by Strongbox on 24/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DatabaseMetadata.h"
#import "DatabaseModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface AutoFillSettingsViewController : NSViewController

@property (nonatomic) DatabaseModel* databaseModel;
@property (nonatomic) DatabaseMetadata* databaseMetadata;

@end

NS_ASSUME_NONNULL_END
