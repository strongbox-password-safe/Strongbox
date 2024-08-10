//
//  DatabaseAuditor.h
//  Strongbox-iOS
//
//  Created by Mark on 17/04/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "DatabaseModel.h"
#import "DatabaseAuditReport.h"
#import "DatabaseAuditorConfiguration.h"
#import "PasswordStrengthConfig.h"

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
    kAuditFlagLowEntropy,
    kAuditFlagTwoFactorAvailable,
};

typedef void (^AuditCompletionBlock)(BOOL userStopped, NSTimeInterval duration);
typedef void (^AuditProgressBlock)(double progress);
typedef void (^AuditNodesChangedBlock)(void);
typedef void (^SaveConfigurationBlock)(DatabaseAuditorConfiguration* config);
typedef BOOL (^IsExcludedBlock)(Node* item);

@interface DatabaseAuditor : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithPro:(BOOL)pro;
- (instancetype)initWithPro:(BOOL)pro
             strengthConfig:(PasswordStrengthConfig*_Nullable)strengthConfig
                 isExcluded:(IsExcludedBlock _Nullable)isExcluded
                 saveConfig:(SaveConfigurationBlock _Nullable)saveConfig NS_DESIGNATED_INITIALIZER;

@property AuditState state;
@property (readonly) CGFloat calculatedProgress;

- (BOOL)start:(DatabaseModel*)database
       config:(DatabaseAuditorConfiguration*)config
 nodesChanged:(AuditNodesChangedBlock)nodesChanged
     progress:(AuditProgressBlock)progress
   completion:(AuditCompletionBlock)completion;

- (void)stop;



- (NSString *)getQuickAuditVeryBriefSummaryForNode:(NSUUID *)item;
- (NSString*)getQuickAuditSummaryForNode:(NSUUID*)item;
- (NSSet<NSNumber*>*)getQuickAuditFlagsForNode:(NSUUID*)node;
- (NSArray<NSString *>*)getQuickAuditAllIssuesVeryBriefSummaryForNode:(NSUUID *)item;
- (NSArray<NSString *>*)getQuickAuditAllIssuesSummaryForNode:(NSUUID *)item;

@property (readonly) NSUInteger auditIssueNodeCount;
@property (readonly) NSUInteger auditIssueCount;


- (DatabaseAuditReport*)getAuditReport;

- (NSSet<NSUUID*>*)getSimilarPasswordNodeSet:(NSUUID*)nodeId;
- (NSSet<NSUUID*>*)getDuplicatedPasswordNodeSet:(NSUUID*)nodeId;

@property (readonly) NSUInteger haveIBeenPwnedErrorCount;

- (void)oneTimeHibpCheck:(NSString*)password completion:(void(^)(BOOL pwned, NSError* error))completion;

@end

NS_ASSUME_NONNULL_END
