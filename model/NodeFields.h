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
@property (nonatomic, strong, nonnull) NSMutableArray<NodeFileAttachment*> *attachments;
@property (nonatomic, strong, nonnull) NSMutableDictionary<NSString*, StringValue*> *customFields;

@property (nonatomic, retain, nonnull) PasswordHistory *passwordHistory; // Password Safe History
@property NSMutableArray<Node*> *keePassHistory;

- (NodeFields *)cloneForHistory;

- (NSMutableArray<NodeFileAttachment*>*)cloneAttachments;
- (NSMutableDictionary<NSString*, StringValue*>*)cloneCustomFields;

@end

NS_ASSUME_NONNULL_END
