//
//  Entry.m
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "Entry.h"
#import "KeePassDatabase.h"
#import "History.h"
#import "SimpleXmlValueExtractor.h"
#import "NSArray+Extensions.h"
#import "Utils.h"

@interface Entry ()

@property (nonatomic) NSMutableDictionary<NSString*, StringValue*> *strings;

@end

@implementation Entry

static NSString* const kTitleStringKey = @"Title";
static NSString* const kUserNameStringKey = @"UserName";
static NSString* const kPasswordStringKey = @"Password";
static NSString* const kUrlStringKey = @"URL";
static NSString* const kNotesStringKey = @"Notes";

const static NSSet<NSString*> *wellKnownKeys;

+ (void)initialize {
    if(self == [Entry class]) {
        wellKnownKeys = [NSSet setWithArray:@[  kTitleStringKey,
                                                kUserNameStringKey,
                                                kPasswordStringKey,
                                                kUrlStringKey,
                                                kNotesStringKey]];
    }
}

+ (const NSSet<NSString*>*)reservedCustomFieldKeys {
    return wellKnownKeys;
}

- (BOOL)isGroup {
    return NO;
}

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    if(self = [super initWithXmlElementName:kEntryElementName context:context]) {
        self.uuid = NSUUID.UUID;
        self.times = [[Times alloc] initWithXmlElementName:kTimesElementName context:context];
        self.history = [[History alloc] initWithXmlElementName:kHistoryElementName context:context];
        self.strings = [NSMutableDictionary dictionary];
        self.binaries = [NSMutableArray array];
        self.tags = [NSMutableSet set];
        self.icon = nil;
        self.customIcon = nil;
        self.customData = [[CustomData alloc] initWithContext:context];
        self.foregroundColor = nil;
        self.backgroundColor = nil;
        self.overrideURL = nil;
        self.autoType = nil;
    }
    
    return self;
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
    if([xmlElementName isEqualToString:kTimesElementName]) {
        return [[Times alloc] initWithContext:self.context];
    }
    else if([xmlElementName isEqualToString:kHistoryElementName]) {
        return [[History alloc] initWithContext:self.context];
    }
    else if([xmlElementName isEqualToString:kStringElementName]) {
        return [[String alloc] initWithContext:self.context];
    }
    else if([xmlElementName isEqualToString:kBinaryElementName]) {
        return [[Binary alloc] initWithContext:self.context];
    }
    else if ([xmlElementName isEqualToString:kCustomDataElementName]) {
        return [[CustomData alloc] initWithContext:self.context];
    }
    else if ([xmlElementName isEqualToString:kAutoTypeElementName] ) {
        return [[KeePassXmlAutoType alloc] initWithContext:self.context];
    }
    
    return [super getChildHandler:xmlElementName];
}

- (BOOL)addKnownChildObject:(id<XmlParsingDomainObject>)completedObject withXmlElementName:(nonnull NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kUuidElementName]) {
        self.uuid = [SimpleXmlValueExtractor getUuid:completedObject];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kTimesElementName]) {
        self.times = (Times*)completedObject;
        return YES;
    }
    else if([withXmlElementName isEqualToString:kHistoryElementName]) {
        self.history = (History*)completedObject;
        return YES;
    }
    else if([withXmlElementName isEqualToString:kStringElementName]) {
        String* str = (String*)completedObject;
        self.strings[str.key] = [StringValue valueWithString:str.value protected:str.protected];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kBinaryElementName]) {
        [self.binaries addObject:(Binary*)completedObject];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kIconIdElementName]) {
        self.icon = [SimpleXmlValueExtractor getNumber:completedObject];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kCustomIconUuidElementName]) {
        self.customIcon = [SimpleXmlValueExtractor getUuid:completedObject];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kTagsElementName]) {
        NSString* tagsString = [SimpleXmlValueExtractor getStringFromText:completedObject];
        
        NSArray<NSString*>* tags = [tagsString componentsSeparatedByString:@";"]; 
        
        NSArray<NSString*>* trimmed = [tags map:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
            return [Utils trim:obj];
        }];
        
        NSArray<NSString*>* filtered = [trimmed filter:^BOOL(NSString * _Nonnull obj) {
            return obj.length > 0;
        }];
        
        [self.tags addObjectsFromArray:filtered];
        
        return YES;
    }
    else if([withXmlElementName isEqualToString:kCustomDataElementName]) {
        self.customData = (CustomData*)completedObject;
        return YES;
    }
    else if([withXmlElementName isEqualToString:kAutoTypeElementName]) {
        self.autoType = (KeePassXmlAutoType*)completedObject;
        return YES;
    }
    else if([withXmlElementName isEqualToString:kForegroundColorElementName]) {
        self.foregroundColor = [SimpleXmlValueExtractor getStringFromText:completedObject];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kBackgroundColorElementName]) {
        self.backgroundColor = [SimpleXmlValueExtractor getStringFromText:completedObject];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kOverrideURLElementName]) {
        self.overrideURL = [SimpleXmlValueExtractor getStringFromText:completedObject];
        return YES;
    }

    return NO;
}

- (BOOL)writeXml:(id<IXmlSerializer>)serializer {
    if(![serializer beginElement:self.originalElementName
                            text:self.originalText
                      attributes:self.originalAttributes]) {
        return NO;
    }
    
    if (![serializer writeElement:kUuidElementName uuid:self.uuid]) return NO;
    if (self.icon && ![serializer writeElement:kIconIdElementName integer:self.icon.integerValue]) return NO;
    if (self.customIcon && ![serializer writeElement:kCustomIconUuidElementName uuid:self.customIcon]) return NO;
    
    for (NSString* key in self.strings.allKeys) {
        StringValue* value = self.strings[key];
        
        
        
        
        

        if(value.protected == NO && value.value.length == 0 && [wellKnownKeys containsObject:key]) {
            continue;
        }

        if(![serializer beginElement:kStringElementName]) {
            return NO;
        }
        
        if(![serializer writeElement:kKeyElementName text:key]) return NO;
        
        
        
        if(![serializer writeElement:kValueElementName text:value.value protected:value.protected trimWhitespace:NO]) {
            return NO;
        }
        
        [serializer endElement];
    }
    
    if(self.binaries) {
        for (Binary *binary in self.binaries) {
            [binary writeXml:serializer];
        }
    }
    
    if(self.times && ![self.times writeXml:serializer]) return NO;
    
    if (self.tags && self.tags.count) {
        NSArray<NSString*>* trimmed = [self.tags.allObjects map:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
            return [Utils trim:obj];
        }];
        
        NSArray<NSString*>* filtered = [trimmed filter:^BOOL(NSString * _Nonnull obj) {
            return obj.length > 0;
        }];

        NSString* str = [[NSSet setWithArray:filtered].allObjects componentsJoinedByString:@";"];
        if ( ![serializer writeElement:kTagsElementName text:str] ) return NO;
    }
    
    if ( self.customData && self.customData.dictionary.count ) {
        if ( ![self.customData writeXml:serializer] ) return NO;
    }

    if ( self.foregroundColor.length ) {
        if ( ![serializer writeElement:kForegroundColorElementName text:self.foregroundColor] ) return NO;
    }
    
    if ( self.backgroundColor.length ) {
        if ( ![serializer writeElement:kBackgroundColorElementName text:self.backgroundColor] ) return NO;
    }
        
    if ( self.overrideURL.length ) {
        if ( ![serializer writeElement:kOverrideURLElementName text:self.overrideURL] ) return NO;
    }
    
    if ( self.autoType ) {
        
        if (!self.autoType.enabled || self.autoType.dataTransferObfuscation != 0 || self.autoType.defaultSequence.length || self.autoType.asssociations.count) {
            if ( ![self.autoType writeXml:serializer] ) return NO;
        }
    }
    
    if(self.history && self.history.entries && self.history.entries.count) {
        [self.history writeXml:serializer];
    }
    
    if(![super writeUnmanagedChildren:serializer]) {
        return NO;
    }
    
    [serializer endElement];
    
    return YES;
}




- (StringValue*)getString:(NSString*)key {
    return self.strings[key];
}

- (NSString*)getStringOrDefault:(NSString*)key {
    StringValue* string = [self getString:key];
    return string == nil || string.value == nil ? @"" : string.value;
}

- (void)setString:(NSString*)key value:(NSString*)value {
    StringValue* string = [self getString:key];
    
    if(!string) {
        self.strings[key] = [StringValue valueWithString:value protected:NO];
    }
    else {
        string.value = value ? value : @"";
    }
}

- (void)setString:(NSString*)key value:(NSString*)value protected:(BOOL)protected {
    StringValue* string = [self getString:key];
    
    if(!string) {
        self.strings[key] = [StringValue valueWithString:value protected:protected];
    }
    else {
        string.value = value ? value : @"";
        string.protected = protected;
    }
}




- (NSString *)title {
    return [self getStringOrDefault:kTitleStringKey];
}

-(void)setTitle:(NSString *)title {
    [self setString:kTitleStringKey value:title protected:NO]; 
}

- (NSString *)username {
    return [self getStringOrDefault:kUserNameStringKey];
}

- (void)setUsername:(NSString *)username {
    [self setString:kUserNameStringKey value:username protected:NO];  
}

- (NSString *)password {
    return [self getStringOrDefault:kPasswordStringKey];
}

- (void)setPassword:(NSString *)password {
    [self setString:kPasswordStringKey value:password protected:YES];  
}

- (NSString *)url {
    return [self getStringOrDefault:kUrlStringKey];
}

- (void)setUrl:(NSString *)url {
    [self setString:kUrlStringKey value:url protected:NO];  
}

- (NSString *)notes {
    return [self getStringOrDefault:kNotesStringKey];
}

- (void)setNotes:(NSString *)notes {
    [self setString:kNotesStringKey value:notes protected:NO];  
}




- (void)removeAllStrings {
    [self.strings removeAllObjects];
}

- (NSDictionary<NSString *,StringValue *> *)allStrings {
    return self.strings;
}

- (NSDictionary<NSString *,StringValue *> *)customStrings {
    NSMutableDictionary<NSString*, StringValue*> *ret = [NSMutableDictionary dictionary];
    
    for (NSString* key in self.strings.allKeys) {
        if(![wellKnownKeys containsObject:key]) {
            StringValue* string = self.strings[key];
            ret[key] = string;
        }
    }
    
    return ret;
}

- (BOOL)isEqual:(id)object {
    if (object == nil) {
        return NO;
    }
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[Entry class]]) {
        return NO;
    }
    
    Entry* other = (Entry*)object;
    if (![self.uuid isEqual:other.uuid]) {
        return NO;
    }
    if (![self.times isEqual:other.times]) {
        return NO;
    }
    if (!(self.icon == nil && other.icon == nil) && ![self.icon isEqual:other.icon]) {
        return NO;
    }
    if (!(self.customIcon == nil && other.customIcon == nil) && ![self.customIcon isEqual:other.customIcon]) {
        return NO;
    }
    if (!(self.allStrings == nil && other.allStrings == nil) && !stringsAreEqual(self.allStrings, other.allStrings)) {
        return NO;
    }
    if (![self.binaries isEqual:other.binaries]) {
        return NO;
    }
    if (![self.history isEqual:other.history]) {
        return NO;
    }
    if (![self.tags isEqualToSet:other.tags]) {
        return NO;
    }
    if ((self.customData == nil && other.customData != nil) || (self.customData != nil && ![self.customData isEqual:other.customData])) {
        return NO;
    }
    if ((self.foregroundColor == nil && other.foregroundColor != nil) || (self.foregroundColor != nil && ![self.foregroundColor isEqual:other.foregroundColor] )) {
        return NO;
    }
    if ((self.backgroundColor == nil && other.backgroundColor != nil) || (self.backgroundColor != nil && ![self.backgroundColor isEqual:other.backgroundColor] )) {
        return NO;
    }
    if ((self.overrideURL == nil && other.overrideURL != nil) || (self.overrideURL != nil && ![self.overrideURL isEqual:other.overrideURL] )) {
        return NO;
    }
    if ((self.autoType == nil && other.autoType != nil) || (self.autoType != nil && ![self.autoType isEqual:other.autoType])) {
        return NO;
    }

    return YES;
}

BOOL stringsAreEqual(NSDictionary<NSString *,StringValue *> * a, NSDictionary<NSString *,StringValue *> * b) {
    return matchesSemantically(a, b) && matchesSemantically(b,a);
}

BOOL matchesSemantically(NSDictionary<NSString *,StringValue *> * a, NSDictionary<NSString *,StringValue *> * b) {
    for(NSString* key in a.allKeys) {
        StringValue *bVal = b[key];
        if(bVal) {
            StringValue *aVal = a[key];
            if(![aVal isEqual:bVal]) {
                return NO;
            }
        }
        else {
            StringValue *aVal = a[key];
            if(aVal.value.length != 0) {
                return NO;
            }
        }
    }
    
    return YES;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"[%@]-[%@]-[%@]-[%@]-[%@]\nUUID = [%@]\nTimes = [%@], iconId = [%@]/[%@]\ncustomFields = [%@]",
            self.title, self.username, self.password, self.url, self.notes, self.uuid, self.times, self.icon, self.customIcon, self.customStrings];
}

@end
