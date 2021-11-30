//
//  SpinnerUI.h
//  Strongbox
//
//  Created by Strongbox on 31/10/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#ifndef SpinnerUI_h
#define SpinnerUI_h

#if TARGET_OS_IPHONE

#import <UIKit/UIKit.h>

typedef UIViewController* VIEW_CONTROLLER_PTR;

#else

#import <Cocoa/Cocoa.h>

typedef NSViewController* VIEW_CONTROLLER_PTR;

#endif

NS_ASSUME_NONNULL_BEGIN

@protocol SpinnerUI <NSObject>

- (void)dismiss;
- (void)show:(NSString*_Nullable)message viewController:(VIEW_CONTROLLER_PTR _Nullable)viewController;

@end

NS_ASSUME_NONNULL_END

#endif /* SpinnerUI_h */
