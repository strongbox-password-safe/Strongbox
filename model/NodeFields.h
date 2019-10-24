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
@property (nonatomic, strong, nullable) NSDate *created;
@property (nonatomic, strong, nullable) NSDate *modified;
@property (nonatomic, strong, nullable) NSDate *accessed;
@property (nonatomic, strong, nullable) NSDate *passwordModified;
@property (nonatomic, strong, nullable) NSDate *expires;
@property (nonatomic, strong, nullable) NSDate *locationChanged;
@property (nonatomic, strong, nullable, readonly) NSNumber *usageCount;

@property (nonatomic, strong, nonnull) NSMutableArray<NodeFileAttachment*> *attachments;
@property (nonatomic, retain, nonnull) PasswordHistory *passwordHistory; // Password Safe History
@property NSMutableArray<Node*> *keePassHistory;

+ (BOOL)isTotpCustomFieldKey:(NSString*)key;

+ (NodeFields *)deserialize:(NSDictionary *)dict;
- (NSDictionary*)serialize:(SerializationPackage*)serialization;

- (NodeFields*)duplicate;
- (NodeFields *)cloneForHistory;

- (NSMutableArray<NodeFileAttachment*>*)cloneAttachments;
- (NSMutableDictionary<NSString*, StringValue*>*)cloneCustomFields;

// Custom Fields

@property (nonatomic, strong, nonnull) NSDictionary<NSString*, StringValue*> *customFields;
- (void)removeAllCustomFields;
- (void)removeCustomField:(NSString*)key;
- (void)setCustomField:(NSString*)key value:(StringValue*)value;

- (void)touch:(BOOL)modified;
- (void)setTouchProperties:(NSDate*_Nullable)accessed modified:(NSDate*_Nullable)modified usageCount:(NSNumber*_Nullable)usageCount;

///////////////////////////////////////////////
// TOTP

@property (nonatomic, readonly) OTPToken* otpToken;

+ (nullable OTPToken*)getOtpTokenFromRecord:(NSString*)password fields:(NSDictionary*)fields notes:(NSString*)notes; // Unit Testing

+ (OTPToken*_Nullable)getOtpTokenFromString:(NSString * _Nonnull)string forceSteam:(BOOL)forceSteam;

- (BOOL)setTotpWithString:(NSString *)string appendUrlToNotes:(BOOL)appendUrlToNotes forceSteam:(BOOL)forceSteam;

- (void)setTotp:(OTPToken*)token appendUrlToNotes:(BOOL)appendUrlToNotes;

- (void)clearTotp;

//

@property (readonly) BOOL expired;
@property (readonly) BOOL nearlyExpired;

@end

NS_ASSUME_NONNULL_END
