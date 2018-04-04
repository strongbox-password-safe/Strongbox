//
//  LockedSafeInfo.m
//  MacBox
//
//  Created by Mark on 21/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "LockedSafeInfo.h"

@implementation LockedSafeInfo

- (instancetype)initWithEncryptedData:(NSData*)encryptedData selectedItem:(NSString*)selectedItem {
    if (self = [super init]) {
        if(encryptedData != nil) {
            _encryptedData = encryptedData;
            _selectedItem = selectedItem;
            
            return self;
        }
    }
    
    return nil;
}

@end
