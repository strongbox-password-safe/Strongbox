//
//  NodeFileAttachment.h
//  Strongbox
//
//  Created by Mark on 01/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NodeFileAttachment : NSObject

+ (instancetype)attachmentWithName:(NSString*)filename index:(uint32_t)index linkedObject:(NSObject*)linkedObject;

@property NSString* filename;
@property uint32_t index;
@property NSObject* linkedObject; // Used to link back to creation object (from Keepass) so that we can recreate xml properly

@end

NS_ASSUME_NONNULL_END
