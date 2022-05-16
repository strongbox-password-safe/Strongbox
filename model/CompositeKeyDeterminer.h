//
//  CompositeKeyDeterminer.h
//  Strongbox
//
//  Created by Strongbox on 06/01/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE

#import <UIKit/UIKit.h>

#else

#import <Cocoa/Cocoa.h>

#endif

#import "CompositeKeyFactors.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, GetCompositeKeyResult) {
    kGetCompositeKeyResultError,
    kGetCompositeKeyResultUserCancelled,
    kGetCompositeKeyResultDuressIndicated,
    kGetCompositeKeyResultSuccess,
};

typedef void(^CompositeKeyDeterminedBlock)(GetCompositeKeyResult result, CompositeKeyFactors*_Nullable factors, BOOL fromConvenience, NSError*_Nullable error);

NS_ASSUME_NONNULL_END
