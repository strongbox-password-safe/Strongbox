//
//  DatabasePreferences.h
//  Strongbox
//
//  Created by Mark on 27/01/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DatabaseMetadata.h"

NS_ASSUME_NONNULL_BEGIN

@interface DatabasePreferences : NSViewController

@property (nonatomic) DatabaseMetadata* metadata;

@end

NS_ASSUME_NONNULL_END
