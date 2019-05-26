//
//  PinEntryController.h
//  Strongbox
//
//  Created by Mark on 11/01/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PinEntryResponse.h"

NS_ASSUME_NONNULL_BEGIN

@interface PinEntryController : UIViewController

@property (nonatomic, copy) void (^onDone)(PinEntryResponse response, NSString* _Nullable pin);

@property NSUInteger pinLength; // Used for Instant PIN Open

@property NSString* info;
@property NSString* warning;
@property BOOL showFallbackOption;

@end

NS_ASSUME_NONNULL_END
