//
//  AppDelegate.h
//  StrongBox
//
//  Created by Mark McGuill on 03/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GoogleSignIn/GoogleSignIn.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate, GIDSignInUIDelegate>

@property (strong, nonatomic) UIWindow *window;

@end
