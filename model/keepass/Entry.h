//
//  Entry.h
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BaseXmlDomainObjectHandler.h"
#import "Times.h"
#import "String.h"
#import "Binary.h"
#import "History.h"
#import "StringValue.h"
#import "KeePassGroupOrEntry.h"
#import "CustomData.h"
#import "KeePassXmlAutoType.h"
#import "MutableOrderedDictionary.h"

NS_ASSUME_NONNULL_BEGIN

@interface Entry : BaseXmlDomainObjectHandler <KeePassGroupOrEntry>

- (instancetype)initWithContext:(XmlProcessingContext*)context;

@property (nonatomic) NSUUID* uuid;
@property (nonatomic, nullable) NSNumber* icon;
@property (nonatomic, nullable) NSUUID* customIcon;
@property (nullable) NSString* foregroundColor;
@property (nullable) NSString* backgroundColor;
@property (nullable) NSString* overrideURL;
@property (nonatomic) NSMutableSet<NSString*> *tags;
@property (nonatomic) Times* times;
@property (nonatomic, nullable) CustomData* customData;
@property (nonatomic) NSMutableArray<Binary*> *binaries;
@property (nullable) KeePassXmlAutoType* autoType;
@property (nonatomic) History* history;



@property (nonatomic) NSString* title;
@property (nonatomic) NSString* username;
@property (nonatomic) NSString* password;
@property (nonatomic) NSString* url;
@property (nonatomic) NSString* notes;
- (void)removeAllStrings;



- (void)setString:(NSString*)key value:(NSString*)value; 
- (void)setString:(NSString*)key value:(NSString*)value protected:(BOOL)protected;






@property (nonatomic, readonly) MutableOrderedDictionary<NSString*, StringValue*> *customStringValues;
@property (nonatomic, readonly) MutableOrderedDictionary<NSString*, StringValue*> *allStringValues;


@property BOOL qualityCheck;
@property (nullable) NSUUID* previousParentGroup;

@end

NS_ASSUME_NONNULL_END
