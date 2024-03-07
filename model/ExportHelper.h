//
//  ExportHelper.h
//  Strongbox
//
//  Created by Strongbox on 25/02/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DatabasePreferences.h"

NS_ASSUME_NONNULL_BEGIN

@interface ExportHelper : NSObject

+ (NSURL*)getExportFile:(DatabasePreferences*)database error:(NSError**)error;
+ (void)cleanupExportFiles:(NSURL *)url;
    
@end

NS_ASSUME_NONNULL_END
