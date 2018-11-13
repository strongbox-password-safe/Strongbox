//
//  AttachmentsRationalizer.h
//  Strongbox-iOS
//
//  Created by Mark on 04/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Node.h"
#import "DatabaseAttachment.h"

NS_ASSUME_NONNULL_BEGIN

@interface AttachmentsRationalizer : NSObject

+ (NSArray<DatabaseAttachment*>*)rationalizeAttachments:(NSArray<DatabaseAttachment*>*)attachments root:(Node*)root;

@end

NS_ASSUME_NONNULL_END
