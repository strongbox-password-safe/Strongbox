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
    kAuditFlagPwned,
};

typedef void (^AuditCompletionBlock)(BOOL userStopped);
typedef void (^AuditProgressBlock)(double progress);
typedef void (^AuditNodesChangedBlock)(void);
typedef BOOL (^AuditIsDereferenceableTextBlock)(NSString* string);
typedef void (^SaveConfigurationBlock)(DatabaseAuditorConfiguration* config);
typedef BOOL (^IsExcludedBlock)(Node* item);

@interface DatabaseAuditor : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithPro:(BOOL)pro;
- (instancetype)initWithPro:(BOOL)pro isExcluded:(IsExcludedBlock _Nullable)isExcluded saveConfig:(SaveConfigurationBlock _Nullable)saveConfig NS_DESIGNATED_INITIALIZER;

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
@property (readonly) NSUInteger auditIssueNodeCount;
@property (readonly) NSUInteger auditIssueCount;


- (DatabaseAuditReport*)getAuditReport;

- (NSSet<Node*>*)getSimilarPasswordNodeSet:(Node*)node;
- (NSSet<Node*>*)getDuplicatedPasswordNodeSet:(Node*)node;

@property (readonly) NSUInteger haveIBeenPwnedErrorCount;

- (void)oneTimeHibpCheck:(NSString*)password completion:(void(^)(BOOL pwned, NSError* error))completion;

@end

NS_ASSUME_NONNULL_END
