//
//  AddNewSafeHelper.h
//  Strongbox
//
//  Created by Mark on 05/12/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeStorageProvider.h"
#import "DatabaseModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface AddNewSafeHelper : NSObject

+ (void)addNewSafeAndPopToRoot:(UIViewController*)vc name:(NSString *)name password:(NSString *)password provider:(id<SafeStorageProvider>)provider format:(DatabaseFormat)format;

@end

NS_ASSUME_NONNULL_END
