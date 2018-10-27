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

static NSString* const kCSVHeaderTitle = @"Title";
static NSString* const kCSVHeaderUsername = @"Username";
static NSString* const kCSVHeaderUrl = @"Url";
static NSString* const kCSVHeaderEmail = @"Email";
static NSString* const kCSVHeaderPassword = @"Password";
static NSString* const kCSVHeaderNotes = @"Notes";

@interface Csv : NSObject

+ (NSData*)getSafeAsCsv:(Node*)rootGroup;

@end

NS_ASSUME_NONNULL_END
