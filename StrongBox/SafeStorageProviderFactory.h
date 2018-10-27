//
//  SafeStorageProviderFactory.h
//  Strongbox-iOS
//
//  Created by Mark on 12/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeStorageProvider.h"

NS_ASSUME_NONNULL_BEGIN

@interface SafeStorageProviderFactory : NSObject

+ (nullable id<SafeStorageProvider>)getStorageProviderFromProviderId:(StorageProvider)providerId;

@end

NS_ASSUME_NONNULL_END
