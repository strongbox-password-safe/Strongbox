//
//  Entry.h
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BaseXmlDomainObjectHandler.h"
#import "GenericTextStringElementHandler.h"
#import "GenericTextUuidElementHandler.h"
#import "Times.h"
#import "String.h"
#import "Binary.h"

NS_ASSUME_NONNULL_BEGIN

@interface Entry : BaseXmlDomainObjectHandler

+ (const NSSet<NSString*>*)reservedCustomFieldKeys;

- (instancetype)initWithContext:(XmlProcessingContext*)context;

@property (nonatomic, nullable) GenericTextStringElementHandler* iconId;
@property (nonatomic, nullable) GenericTextUuidElementHandler* customIconUuid;
@property (nonatomic) GenericTextUuidElementHandler* uuid;
@property (nonatomic) Times* times;
@property (nonatomic) NSMutableArray<String*> *strings;
@property (nonatomic) NSMutableArray<Binary*> *binaries;

@property (nonatomic) NSNumber* icon;
@property (nonatomic, nullable) NSUUID* customIcon;

// Customized Getters/Setters for well-known fields - basically views on the strings collection

@property (nonatomic) NSString* title;
@property (nonatomic) NSString* username;
@property (nonatomic) NSString* password;
@property (nonatomic) NSString* url;
@property (nonatomic) NSString* notes;

// Safe Custom String setter...

- (void)setString:(NSString*)key value:(NSString*)value protected:(BOOL)protected;

// R/O Handy View

@property (nonatomic, readonly) NSDictionary<NSString*, NSString*> *customFields;

@end

NS_ASSUME_NONNULL_END
