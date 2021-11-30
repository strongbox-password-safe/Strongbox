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
#import "SafeMetaData.h"

typedef UIViewController* VIEW_CONTROLLER_PTR;
typedef SafeMetaData* METADATA_PTR;

#else

#import <Cocoa/Cocoa.h>
#import "DatabaseMetadata.h"

typedef NSViewController* VIEW_CONTROLLER_PTR;
typedef DatabaseMetadata* METADATA_PTR;

#endif

#import "CompositeKeyFactors.h"

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    kGetCompositeKeyResultError,
    kGetCompositeKeyResultUserCancelled,
    kGetCompositeKeyResultDuressIndicated,
    kGetCompositeKeyResultSuccess,
} GetCompositeKeyResult;

typedef void(^CompositeKeyDeterminedBlock)(GetCompositeKeyResult result, CompositeKeyFactors*_Nullable factors, BOOL fromConvenience, NSError*_Nullable error);

NS_ASSUME_NONNULL_END
