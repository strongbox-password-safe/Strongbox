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

@property (weak, nonatomic) IBOutlet UILabel *labelSubtitle;
@property (weak, nonatomic) IBOutlet UITextField *textFieldPin;
@property (weak, nonatomic) IBOutlet UILabel *labelWarning;
@property (nonatomic, copy) void (^onDone)(PinEntryResponse response, NSString* _Nullable pin);

@property NSString* info;
@property NSString* warning;
@property BOOL showFallbackOption;

@property (weak, nonatomic) IBOutlet UIButton *buttonOK;
@property (weak, nonatomic) IBOutlet UIButton *buttonMasterFallback;

@end

NS_ASSUME_NONNULL_END
