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

+ (void)getExportFile:(UIViewController*)viewController database:(DatabasePreferences*)database completion:(void(^)(NSURL*_Nullable url, NSError *_Nullable error))completion;
+ (void)cleanupExportFiles:(NSURL *)url;
    
@end

NS_ASSUME_NONNULL_END
