//
//  Csv.h
//  Strongbox-iOS
//
//  Created by Mark on 09/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DatabaseModel.h"

NS_ASSUME_NONNULL_BEGIN

static NSString* const kCSVHeaderTitle = @"Title";
static NSString* const kCSVHeaderUsername = @"Username";
static NSString* const kCSVHeaderUrl = @"URL";
static NSString* const kCSVHeaderEmail = @"Email";
static NSString* const kCSVHeaderPassword = @"Password";
static NSString* const kCSVHeaderNotes = @"Notes";
static NSString* const kCSVHeaderTotp = @"OTPAuth";

@interface Csv : NSObject

+ (NSData*)getGroupAsCsv:(Node*_Nullable)database;
+ (NSData*)getNodesAsCsv:(NSArray<Node*>*)nodes;

@end

NS_ASSUME_NONNULL_END
