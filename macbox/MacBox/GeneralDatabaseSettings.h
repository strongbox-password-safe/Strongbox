//
//  GeneralDatabaseSettings.h
//  MacBox
//
//  Created by Strongbox on 24/03/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DatabaseModel.h"
#import "DatabaseMetadata.h"

NS_ASSUME_NONNULL_BEGIN

@interface GeneralDatabaseSettings : NSViewController

@property (nonatomic) DatabaseModel* databaseModel;
@property (nonatomic) DatabaseMetadata* databaseMetadata;

@end

NS_ASSUME_NONNULL_END
