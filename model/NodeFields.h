//
//  NodeFields.h
//  MacBox
//
//  Created by Mark on 31/08/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PasswordHistory.h"
#import "StringValue.h"
#import "OTPToken.h"
#import "SerializationPackage.h"
#import "MutableOrderedDictionary.h"
#import "AutoType.h"
#import "SyncComparisonParams.h"
#import "ValueWithModDate.h"

extern NSString* _Nonnull const kOtpAuthScheme;

@class Node;

NS_ASSUME_NONNULL_BEGIN

@interface NodeFields : NSObject

- (instancetype)init;

- (instancetype)initWithUsername:(NSString*_Nonnull)username
                                       url:(NSString*_Nonnull)url
                                  password:(NSString*_Nonnull)password
                                     notes:(NSString*_Nonnull)notes
                                     email:(NSString*_Nonnull)email NS_DESIGNATED_INITIALIZER;




@property (nonatomic, strong, nonnull) NSString *password;
@property (nonatomic, strong, nonnull) NSString *username;
@property (nonatomic, strong, nonnull) NSString *url;
@property (nonatomic, strong, nonnull) NSString *notes;

@property (nonnull) NSString *email; 

@property (readonly, nonatomic, strong, nullable) NSDate *created;
@property (readonly, nonatomic, strong, nullable) NSDate *modified;
@property (readonly, nonatomic, strong, nullable) NSDate *accessed;
@property (readonly, nonatomic, strong, nullable) NSDate *locationChanged;
@property (readonly, nonatomic, strong, nullable, readonly) NSNumber *usageCount;
@property (nonatomic, strong, nullable) NSDate *passwordModified;
@property (nonatomic, strong, nullable) NSDate *expires;
@property (nonatomic, strong, nonnull) NSMutableDictionary<NSString*, KeePassAttachmentAbstractionLayer*> *attachments;
@property (nonatomic, strong, nonnull) NSMutableSet<NSString*> *tags;
@property (nonatomic, retain, nonnull) PasswordHistory *passwordHistory; 
@property NSMutableArray<Node*> *keePassHistory;
@property NSMutableDictionary<NSString*, ValueWithModDate*> *customData;

@property (nonatomic, nullable) NSString* defaultAutoTypeSequence;
@property (nonatomic, nullable) NSNumber* enableAutoType;
@property (nonatomic, nullable) NSNumber* enableSearching;
@property (nonatomic, nullable) NSUUID* lastTopVisibleEntry;
@property (nullable) NSString* foregroundColor;
@property (nullable) NSString* backgroundColor;
@property (nullable) NSString* overrideURL;
@property (nullable) AutoType* autoType;
@property BOOL isExpanded;
@property BOOL qualityCheck; 
@property BOOL isAutoFillExcluded; 
@property (nullable) NSUUID* previousParentGroup;



+ (BOOL)isTotpCustomFieldKey:(NSString*)key;
+ (BOOL)isPasskeyCustomFieldKey:(NSString*)key;
+ (BOOL)isAlternativeURLCustomFieldKey:(NSString*)key;

- (void)addSecondaryUrl:(NSString*)url optionalCustomFieldSuffixLabel:(NSString*_Nullable)optionalCustomFieldSuffixLabel;

+ (NodeFields *)deserialize:(NSDictionary *)dict;
- (NSDictionary*)serialize:(SerializationPackage*)serialization;

- (NodeFields*)cloneOrDuplicate:(BOOL)cloneTouchProperties;

- (void)mergePropertiesInFromNode:(NodeFields *)mergeNodeFields mergeLocationChangedDate:(BOOL)mergeLocationChangedDate includeHistory:(BOOL)includeHistory;

- (void)restoreFromHistoricalNode:(NodeFields*)historicalFields;

- (BOOL)isSyncEqualTo:(NodeFields*)other isForUIDiffReport:(BOOL)isForUIDiffReport checkHistory:(BOOL)checkHistory;



@property (nonatomic, strong, nonnull) MutableOrderedDictionary<NSString*, StringValue*> *customFields;
@property (readonly, nonatomic, strong, nonnull) MutableOrderedDictionary<NSString*, StringValue*> *customFieldsNoEmail;
@property (readonly, nonatomic, strong, nonnull) MutableOrderedDictionary<NSString *,StringValue *> *customFieldsFiltered;

- (void)removeAllCustomFields;
- (void)removeCustomField:(NSString*)key;
- (void)setCustomField:(NSString*)key value:(StringValue*)value;


- (void)touch:(BOOL)modified;
- (void)touch:(BOOL)modified date:(NSDate*)date;

- (void)touchLocationChanged;
- (void)touchLocationChanged:(NSDate*)date;

- (void)setModifiedDateExplicit:(const NSDate*)modified;
- (void)setTouchPropertiesWithAccessed:(const NSDate*)accessed modified:(const NSDate*)modified usageCount:(const NSNumber*)usageCount;
- (void)setTouchPropertiesWithCreated:(const NSDate*_Nullable)created accessed:(const NSDate*_Nullable)accessed modified:(const NSDate*_Nullable)modified locationChanged:(const NSDate*_Nullable)locationChanged usageCount:(const NSNumber*_Nullable)usageCount;




@property (nonatomic, nullable, readonly) OTPToken* otpToken;

+ (nullable OTPToken*)getOtpTokenFromRecord:(NSString*)password fields:(NSDictionary*)fields notes:(NSString*)notes; 

+ (OTPToken*_Nullable)getOtpTokenFromString:(NSString *)string
                                 forceSteam:(BOOL)forceSteam;

+ (OTPToken*_Nullable)getOtpTokenFromString:(NSString *)string
                                 forceSteam:(BOOL)forceSteam
                                     issuer:(NSString*_Nullable)issuer
                                   username:(NSString*_Nullable)username;

- (void)setTotp:(OTPToken*)token appendUrlToNotes:(BOOL)appendUrlToNotes addLegacyFields:(BOOL)addLegacyFields addOtpAuthUrl:(BOOL)addOtpAuthUrl;

- (void)clearTotp;



@property (readonly) BOOL expired;
@property (readonly) BOOL nearlyExpired;

+ (BOOL)nearlyExpired:(NSDate*)expires;



@property (readonly) NSArray<NSString*> *alternativeUrls;

@end

NS_ASSUME_NONNULL_END
