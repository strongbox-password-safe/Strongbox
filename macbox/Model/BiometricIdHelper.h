//
//  BiometricIdHelper.h
//  Macbox
//
//  Created by Mark on 04/04/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface BiometricIdHelper : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic, strong) NSString* biometricIdName;
@property (nonatomic) BOOL biometricIdAvailable;

@end
