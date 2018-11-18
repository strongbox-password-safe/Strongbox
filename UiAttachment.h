//
//  UiAttachment.h
//  Strongbox
//
//  Created by Mark on 17/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UiAttachment : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithFilename:(NSString*)filename data:(NSData*)data NS_DESIGNATED_INITIALIZER;

@property NSString* filename;
@property NSData* data;

@end

NS_ASSUME_NONNULL_END
