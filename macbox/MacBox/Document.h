//
//  Document.h
//  MacBox
//
//  Created by Mark on 01/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AbstractDatabaseFormatAdaptor.h"

NS_ASSUME_NONNULL_BEGIN

@interface Document : NSDocument

- (instancetype)initWithCredentials:(DatabaseFormat)format password:(nullable NSString*)password keyFileDigest:(nullable NSData*)keyFileDigest;

- (void)revertWithUnlock:(NSString*_Nullable)password
           keyFileDigest:(NSData*_Nullable)keyFileDigest
            selectedItem:(NSString*_Nullable)selectedItem
              completion:(void(^)(BOOL success, NSError*_Nullable error))completion;

NS_ASSUME_NONNULL_END

@end

