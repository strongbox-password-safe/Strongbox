//
//  QRCodeScannerViewController.h
//  Strongbox-iOS
//
//  Created by Mark on 21/01/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface QRCodeScannerViewController : UIViewController

@property (nonatomic, copy) void (^onDone)(BOOL response, NSString* string);

@property (weak, nonatomic) IBOutlet UIView *cameraView;

@end

NS_ASSUME_NONNULL_END
