//
//  LockedSafeInfo.h
//  MacBox
//
//  Created by Mark on 21/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LockedSafeInfo : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithEncryptedData:(NSData*)encryptedData selectedItem:(NSString*)selectedItem NS_DESIGNATED_INITIALIZER;

@property (strong, nonatomic, readonly) NSData* encryptedData;
@property (strong, nonatomic, readonly) NSString* selectedItem;

@end
