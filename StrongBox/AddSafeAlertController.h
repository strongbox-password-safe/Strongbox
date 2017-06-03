//
//  AddSafeAlertController.h
//  StrongBox
//
//  Created by Mark on 30/05/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef BOOL (^ExistingValidation)(NSString *name);
typedef BOOL (^NewValidation)(NSString *name, NSString *password);

@interface AddSafeAlertController : NSObject

- (void)addNew:(UIViewController *)viewController
    validation:(BOOL (^)(NSString *name, NSString *password))validation
    completion:(void (^)(NSString *name, NSString *password, BOOL response))completion;

- (void)addExisting:(UIViewController *)viewController
         validation:(BOOL (^)(NSString *name))validation
         completion:(void (^)(NSString *name, BOOL response))completion;

@end
