//
//  NodeFields.h
//  MacBox
//
//  Created by Mark on 31/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PasswordHistory.h"
#import "NodeFileAttachment.h"
#import "StringValue.h"
#import "OTPToken.h"
#import "SerializationPackage.h"
#import "MutableOrderedDictionary.h"
#import "AutoType.h"
#import "SyncComparisonParams.h"

@class Node;

NS_ASSUME_NONNULL_BEGIN

@interface NodeFields : NSObject

- (instancetype _Nullable)init;

- (instancetype _Nullable)initWithUsername:(NSString*_Nonnull)username
                                       url:(NSString*_Nonnull)url
                                  password:(NSString*_Nonnull)password
                                     notes:(NSString*_Nonnull)notes
                                     email:(NSString*_Nonnull)email NS_DESIGNATED_INITIALIZER;

@property (nonatomic, strong, nonnull) NSString *password;
@property (nonatomic, strong, nonnull) NSString *username;
@property (nonatomic, strong, nonnull) NSString *email;
@property (nonatomic, strong, nonnull) NSString *url;
@property (nonatomic, strong, nonnull) NSString *notes;
@property (readonly, nonatomic, strong, nullable) NSDate *created;
@property (readonly, nonatomic, strong, nullable) NSDate *modified;
@property (readonly, nonatomic, strong, nullable) NSDate *accessed;
@property (readonly, nonatomic, strong, nullable) NSDate *locationChanged;
@property (readonly, nonatomic, strong, nullable, readonly) NSNumber *usageCount;
@property (nonatomic, strong, nullable) NSDate *passwordModified;
@property (nonatomic, strong, nullable) NSDate *expires;
@property (nonatomic, strong, nonnull) NSMutableArray<NodeFileAttachment*> *attachments;
@property (nonatomic, strong, nonnull) NSMutableSet<NSString*> *tags;
@property (nonatomic, retain, nonnull) PasswordHistory *passwordHistory; 
@property NSMutableArray<Node*> *keePassHistory;
@property MutableOrderedDictionary<NSString*, NSString*> *customData;

@property (nonatomic, nullable) NSString* defaultAutoTypeSequence;
@property (nonatomic, nullable) NSNumber* enableAutoType;
@property (nonatomic, nullable) NSNumber* enableSearching;
@property (nonatomic, nullable) NSUUID* lastTopVisibleEntry;
@property (nullable) NSString* foregroundColor;
@property (nullable) NSString* backgroundColor;
@property (nullable) NSString* overrideURL;
@property (nullable) AutoType* autoType;

+ (BOOL)isTotpCustomFieldKey:(NSString*)key;

+ (NodeFields *)deserialize:(NSDictionary *)dict;
- (NSDictionary*)serialize:(SerializationPackage*)serialization;

- (NodeFields*)cloneOrDuplicate:(BOOL)clearHistory cloneTouchProperties:(BOOL)cloneTouchProperties;

- (BOOL)isSyncEqualTo:(NodeFields*)other params:(SyncComparisonParams *)params;

- (NSMutableArray<NodeFileAttachment*>*)cloneAttachments;
- (NSMutableDictionary<NSString*, StringValue*>*)cloneCustomFields;



@property (nonatomic, strong, nonnull) NSDictionary<NSString*, StringValue*> *customFields;
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




@property (nonatomic, readonly) OTPToken* otpToken;

+ (nullable OTPToken*)getOtpTokenFromRecord:(NSString*)password fields:(NSDictionary*)fields notes:(NSString*)notes; 

+ (OTPToken*_Nullable)getOtpTokenFromString:(NSString *)string
                                 forceSteam:(BOOL)forceSteam
                                     issuer:(NSString*)issuer
                                   username:(NSString*)username;

- (void)setTotp:(OTPToken*)token appendUrlToNotes:(BOOL)appendUrlToNotes;

- (void)clearTotp;



@property (readonly) BOOL expired;
@property (readonly) BOOL nearlyExpired;



@property (readonly) NSArray<NSString*> *alternativeUrls;

@end

NS_ASSUME_NONNULL_END
