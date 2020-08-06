//
//  LegacySyncReadOptions.h
//  Strongbox
//
//  Created by Strongbox on 20/06/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SyncReadOptions : NSObject

@property BOOL isAutoFill; // TODO: Should be able to get rid of this once Auto-Fill moves to local only
@property (nullable) UIViewController* vc; // If null -> Try to Background Sync
@property BOOL joinInProgressSync; 

@end

NS_ASSUME_NONNULL_END
