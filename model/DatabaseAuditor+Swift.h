#import <Foundation/Foundation.h>

#import "DatabaseAuditor.h"

@class ConcurrentMutableSet;
@class DatabaseAuditorConfiguration;
@class DatabaseModel;
@class PasswordStrengthConfig;
@class Node;

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseAuditor (SwiftInterop)

@property (nonatomic) BOOL stopRequested;
@property (nonatomic, strong) DatabaseAuditorConfiguration *config;
@property (nonatomic, strong) DatabaseModel *database;
@property (nonatomic) BOOL isPro;
@property (nonatomic, strong, nullable) PasswordStrengthConfig *strengthConfig;
@property (nullable, nonatomic, copy) SaveConfigurationBlock saveConfig;
@property (nullable, nonatomic, copy) IsExcludedBlock isExcluded;
@property (nonatomic, strong) NSArray<Node *> *auditableNonEmptyPasswordNodes;

@property (nonatomic, strong) NSSet<NSUUID *> *twoFactorAvailable;
@property (nonatomic, strong) NSSet<NSUUID *> *commonPasswords;
@property (nonatomic, strong) NSSet<NSUUID *> *lowEntropy;
@property (nonatomic, strong) NSDictionary<NSString *, NSSet<NSUUID *> *> *duplicatedPasswords;
@property (nonatomic, strong) NSSet<NSUUID *> *noPasswords;
@property (nonatomic, strong) NSDictionary<NSUUID *, NSSet<NSUUID *> *> *similar;
@property (nonatomic, strong) NSSet<NSUUID *> *tooShort;
@property (nonatomic, strong) NSSet<NSUUID *> *duplicatedPasswordsNodeSet;
@property (nonatomic, strong) NSSet<NSUUID *> *similarPasswordsNodeSet;
@property (nonatomic, strong) ConcurrentMutableSet<NSUUID *> *mutablePwnedNodes;
@property (nonatomic, strong) ConcurrentMutableSet<NSUUID *> *mutableBreachedAccountNodes;
@property (nonatomic, strong) NSMutableDictionary<NSUUID *, NSArray<NSString *> *> *matchedBreachedDomainsByNode;

@property (nonatomic, strong) NSOperationQueue *hibpQueue;
@property (nonatomic) NSUInteger hibpErrorCount;
@property (nonatomic, strong) NSMutableArray<NSString *> *hibpErrorReasons;
@property (nonatomic) NSUInteger hibpCompletedCount;
@property (nonatomic) NSUInteger hibpTotalCount;
@property (nonatomic) CGFloat hibpProgress;
@property (nonatomic) CGFloat similarProgress;

@end

NS_ASSUME_NONNULL_END
