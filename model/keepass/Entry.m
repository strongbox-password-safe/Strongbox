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
#import "MutableOrderedDictionary.h"
#import "Constants.h"

@interface Entry ()

@property (nonatomic) MutableOrderedDictionary<NSString*, StringValue*> *strings;
@property (nonatomic, readonly) MutableOrderedDictionary<NSString*, StringValue*> *nonCustomStringValues;

@end

@implementation Entry

+ (void)initialize {
    if(self == [Entry class]) {
    }
}

- (BOOL)isGroup {
    return NO;
}

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    if(self = [super initWithXmlElementName:kEntryElementName context:context]) {
        self.uuid = NSUUID.UUID;
        self.times = [[Times alloc] initWithXmlElementName:kTimesElementName context:context];
        self.history = [[History alloc] initWithXmlElementName:kHistoryElementName context:context];
        self.strings = [[MutableOrderedDictionary alloc] init];
        self.binaries = [NSMutableArray array];
        self.tags = [NSMutableSet set];
        self.icon = nil; 
        self.customIcon = nil;
        self.customData = [[CustomData alloc] initWithContext:context];
        self.foregroundColor = nil;
        self.backgroundColor = nil;
        self.overrideURL = nil;
        self.autoType = nil;
        self.qualityCheck = YES;
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
        
        NSArray<NSString*>* tags = [Utils getTagsFromTagString:tagsString];

        [self.tags addObjectsFromArray:tags];
        
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
    else if([withXmlElementName isEqualToString:kQualityCheckElementName]) {
        self.qualityCheck = [SimpleXmlValueExtractor getBool:completedObject defaultValue:YES];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kPreviousParentGroupElementName]) {
        self.previousParentGroup = [SimpleXmlValueExtractor getUuid:completedObject];
        return YES;
    }

    return NO;
}

- (BOOL)writeXml:(id<IXmlSerializer>)serializer {
    @autoreleasepool {
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
            
            
            
            
            

            if(value.protected == NO && value.value.length == 0 && [Constants.ReservedCustomFieldKeys containsObject:key]) {
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
        
        if ( !self.qualityCheck ) { 
            if ( ![serializer writeElement:kQualityCheckElementName boolean:self.qualityCheck] ) return NO;
        }
        
        if ( self.autoType ) {
            
            if (!self.autoType.enabled || self.autoType.dataTransferObfuscation != 0 || self.autoType.defaultSequence.length || self.autoType.asssociations.count) {
                if ( ![self.autoType writeXml:serializer] ) return NO;
            }
        }
        
        if(self.history && self.history.entries && self.history.entries.count) {
            [self.history writeXml:serializer];
        }
        
        if ( self.previousParentGroup ) {
            if ( ![serializer writeElement:kPreviousParentGroupElementName uuid:self.previousParentGroup]) return NO;
        }
        
        if(![super writeUnmanagedChildren:serializer]) {
            return NO;
        }
        
        [serializer endElement];
        
        return YES;
    }
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

- (MutableOrderedDictionary<NSString *,StringValue *> *)allStringValues {
    return self.strings;
}

- (MutableOrderedDictionary<NSString *,StringValue *> *)nonCustomStringValues {
    MutableOrderedDictionary<NSString*, StringValue*> *ret = [[MutableOrderedDictionary alloc] init];
    
    for (NSString* key in self.strings.allKeys) {
        if([Constants.ReservedCustomFieldKeys containsObject:key]) {
            StringValue* string = self.strings[key];
            ret[key] = string;
        }
    }
    
    return ret;
}

- (MutableOrderedDictionary<NSString *,StringValue *> *)customStringValues {
    MutableOrderedDictionary<NSString*, StringValue*> *ret = [[MutableOrderedDictionary alloc] init];
    
    for (NSString* key in self.strings.allKeys) {
        if(![Constants.ReservedCustomFieldKeys containsObject:key]) {
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

    
    









    if ( ![self.title isEqualToString:other.title] ) {
        return NO;
    }
    
    if ( ![self.username isEqualToString:other.username] ) {
        return NO;
    }
    
    if ( ![self.password isEqualToString:other.password] ) {
        return NO;
    }
    
    if ( ![self.url isEqualToString:other.url] ) {
        return NO;
    }
    
    if ( ![self.notes isEqualToString:other.notes] ) {
        return NO;
    }
    
    if ( ![self.customStringValues isEqual:other.customStringValues] ) {
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
    if ( self.qualityCheck != other.qualityCheck ) {
        return NO;
    }
    if ((self.previousParentGroup == nil && other.previousParentGroup != nil) || (self.previousParentGroup != nil && ![self.previousParentGroup isEqual:other.previousParentGroup] )) {
        return NO;
    }

    return YES;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"[%@]-[%@]-[%@]-[%@]-[%@]\nUUID = [%@]\nTimes = [%@], iconId = [%@]/[%@]\ncustomFields = [%@]",
            self.title, self.username, self.password, self.url, self.notes, self.uuid, self.times, self.icon, self.customIcon, self.customStringValues];
}

@end
