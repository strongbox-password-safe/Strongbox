//
//  StorageProviderReadResult.h
//  Strongbox
//
//  Created by Strongbox on 04/07/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM (NSUInteger, StorageProviderReadResult) {
    kReadResultError,
    kReadResultSuccess,
    kReadResultBackgroundReadButUserInteractionRequired,
    kReadResultModifiedIsSameAsLocal,
    kReadResultUnavailable, 
};

NS_ASSUME_NONNULL_END
