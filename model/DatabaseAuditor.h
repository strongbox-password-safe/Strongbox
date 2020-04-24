//
//  DatabaseAuditor.h
//  Strongbox-iOS
//
//  Created by Mark on 17/04/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "DatabaseModel.h"
#import "DatabaseAuditReport.h"
#import "DatabaseAuditorConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM (unsigned int, AuditState) {
    kAuditStateInitial,
    kAuditStateRunning,
    kAuditStateStoppedIncomplete,
    kAuditStateDone,
};

typedef NS_ENUM (unsigned int, AuditFlag) {
    kAuditFlagNoPassword,
    kAuditFlagCommonPassword,
    kAuditFlagDuplicatePassword,
    kAuditFlagSimilarPassword,
};

typedef void (^AuditCompletionBlock)(BOOL userStopped);
typedef void (^AuditProgressBlock)(CGFloat progress);
typedef BOOL (^AuditIsDereferenceableTextBlock)(NSString* string);

@interface DatabaseAuditor : NSObject

@property AuditState state;

- (BOOL)start:(NSArray<Node*>*)nodes
       config:(DatabaseAuditorConfiguration*)config
isDereferenceable:(AuditIsDereferenceableTextBlock)isDereferenceable
     progress:(AuditProgressBlock)progress
   completion:(AuditCompletionBlock)completion;

- (void)stop;

- (NSSet<NSNumber*>*)getQuickAuditFlagsForNode:(Node*)node;
- (DatabaseAuditReport*)getAuditReport;

@end

NS_ASSUME_NONNULL_END
