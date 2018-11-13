//
//  Attachment.h
//  Strongbox
//
//  Created by Mark on 01/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseAttachment : NSObject

@property NSData* data;
@property BOOL compressed; // Keepass v3
@property BOOL protectedInMemory; // Keepass v4

@end

NS_ASSUME_NONNULL_END
