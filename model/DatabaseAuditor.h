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
    kAuditFlagTooShort,
};

typedef void (^AuditCompletionBlock)(BOOL userStopped);
typedef void (^AuditProgressBlock)(CGFloat progress);
typedef void (^AuditNodesChangedBlock)(void);
typedef BOOL (^AuditIsDereferenceableTextBlock)(NSString* string);

@interface DatabaseAuditor : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithPro:(BOOL)pro NS_DESIGNATED_INITIALIZER;

@property AuditState state;

- (BOOL)start:(NSArray<Node*>*)nodes
       config:(DatabaseAuditorConfiguration*)config
isDereferenceable:(AuditIsDereferenceableTextBlock)isDereferenceable
 nodesChanged:(AuditNodesChangedBlock)nodesChanged
     progress:(AuditProgressBlock)progress
   completion:(AuditCompletionBlock)completion;

- (void)stop;

- (NSString *)getQuickAuditVeryBriefSummaryForNode:(Node *)item;
- (NSString*)getQuickAuditSummaryForNode:(Node*)item;

- (NSSet<NSNumber*>*)getQuickAuditFlagsForNode:(Node*)node;
- (DatabaseAuditReport*)getAuditReport;

@property (readonly) NSUInteger auditIssueNodeCount;
@property (readonly) NSUInteger auditIssueCount;

@end

NS_ASSUME_NONNULL_END
