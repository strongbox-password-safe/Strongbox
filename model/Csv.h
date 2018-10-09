//
//  Csv.h
//  Strongbox-iOS
//
//  Created by Mark on 09/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Node.h"

NS_ASSUME_NONNULL_BEGIN

static NSString* kCSVHeaderTitle = @"Title";
static NSString* kCSVHeaderUsername = @"Username";
static NSString* kCSVHeaderUrl = @"Url";
static NSString* kCSVHeaderEmail = @"Email";
static NSString* kCSVHeaderPassword = @"Password";
static NSString* kCSVHeaderNotes = @"Notes";

@interface Csv : NSObject

+ (NSData*)getSafeAsCsv:(Node*)rootGroup;

@end

NS_ASSUME_NONNULL_END
