//
//  DatabasePropertiesController.h
//  Strongbox
//
//  Created by Mark on 27/01/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DatabaseModel.h"
#import "DatabaseMetadata.h"
#import "ViewModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseSettingsTabViewController : NSTabViewController

+ (instancetype)fromStoryboard;
- (void)setModel:(ViewModel*)model initialTab:(NSInteger)initialTab;

@end

NS_ASSUME_NONNULL_END
