//
//  AppDelegate.h
//  StrongBox
//
//  Created by Mark McGuill on 03/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic, nullable) UIWindow *window;
@property (readonly) BOOL isAppLocked;
@property (nullable) NSDate* appLaunchTime;

- (UIViewController*_Nullable)getVisibleViewController;

@end
