//
//  UiAttachment.h
//  Strongbox
//
//  Created by Mark on 17/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DatabaseAttachment.h"

NS_ASSUME_NONNULL_BEGIN

@interface UiAttachment : NSObject

+ (instancetype)attachmentWithFilename:(NSString*)filename dbAttachment:(DatabaseAttachment*)dbAttachment;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithFilename:(NSString*)filename dbAttachment:(DatabaseAttachment*)dbAttachment NS_DESIGNATED_INITIALIZER;

@property NSString* filename;
@property DatabaseAttachment* dbAttachment;

@end

NS_ASSUME_NONNULL_END
