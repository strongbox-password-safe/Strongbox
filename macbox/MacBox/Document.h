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

//- (void)foo:(Node*)item;

NS_ASSUME_NONNULL_END

@end

