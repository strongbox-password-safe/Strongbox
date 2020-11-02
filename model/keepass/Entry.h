//
//  Entry.h
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BaseXmlDomainObjectHandler.h"
#import "Times.h"
#import "String.h"
#import "Binary.h"
#import "History.h"
#import "StringValue.h"
#import "KeePassGroupOrEntry.h"

NS_ASSUME_NONNULL_BEGIN

@interface Entry : BaseXmlDomainObjectHandler <KeePassGroupOrEntry>

+ (const NSSet<NSString*>*)reservedCustomFieldKeys;

- (instancetype)initWithContext:(XmlProcessingContext*)context;

@property (nonatomic) NSUUID* uuid;
@property (nonatomic) Times* times;
@property (nonatomic) NSMutableArray<Binary*> *binaries;
@property (nonatomic) History* history;
@property (nonatomic) NSMutableSet<NSString*> *tags;

@property (nonatomic, nullable) NSNumber* icon;
@property (nonatomic, nullable) NSUUID* customIcon;

// Customized Getters/Setters for well-known fields - basically views on the strings collection

@property (nonatomic) NSString* title;
@property (nonatomic) NSString* username;
@property (nonatomic) NSString* password;
@property (nonatomic) NSString* url;
@property (nonatomic) NSString* notes;

- (void)removeAllStrings;

// Safe Custom String setter...

- (void)setString:(NSString*)key value:(NSString*)value; // Do not change protected attribute
- (void)setString:(NSString*)key value:(NSString*)value protected:(BOOL)protected;

// R/O Handy View

@property (nonatomic, readonly) NSDictionary<NSString*, StringValue*> *customStrings;
@property (nonatomic, readonly) NSDictionary<NSString*, StringValue*> *allStrings;

@end

NS_ASSUME_NONNULL_END
