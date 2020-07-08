//
//  StorageProviderReadOptions.h
//  Strongbox
//
//  Created by Strongbox on 04/07/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface StorageProviderReadOptions : NSObject

@property BOOL isAutoFill; // TODO: We can get rid of this in Uber Sync - used only by Files app to read a different bookmark in Auto Fill
@property (nullable) NSDate* onlyIfModifiedDifferentFrom;
@property BOOL interactiveAllowed;

@end

NS_ASSUME_NONNULL_END
