//
//  Entry.m
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "Entry.h"
#import "KeePassDatabase.h"
#import "History.h"

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

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    if(self = [super initWithXmlElementName:kEntryElementName context:context]) {
        self.uuid = [[GenericTextUuidElementHandler alloc] initWithXmlElementName:kUuidElementName context:context];
        self.times = [[Times alloc] initWithXmlElementName:kTimesElementName context:context];
        self.history = [[History alloc] initWithXmlElementName:kHistoryElementName context:context];
        self.strings = [NSMutableDictionary dictionary];
        self.binaries = [NSMutableArray array];
        self.iconId = nil;
        self.customIconUuid = nil;
    }
    
    return self;
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
    if([xmlElementName isEqualToString:kUuidElementName]) {
        return [[GenericTextUuidElementHandler alloc] initWithXmlElementName:kUuidElementName context:self.context];
    }
    else if([xmlElementName isEqualToString:kTimesElementName]) {
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
    else if([xmlElementName isEqualToString:kIconIdElementName]) {
        return [[GenericTextStringElementHandler alloc] initWithXmlElementName:kIconIdElementName context:self.context];
    }
    else if([xmlElementName isEqualToString:kCustomIconUuidElementName]) {
        return [[GenericTextUuidElementHandler alloc] initWithXmlElementName:kCustomIconUuidElementName context:self.context];
    }
    
    return [super getChildHandler:xmlElementName];
}

- (BOOL)addKnownChildObject:(nonnull NSObject *)completedObject withXmlElementName:(nonnull NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kUuidElementName]) {
        self.uuid = (GenericTextUuidElementHandler*)completedObject;
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
        self.iconId = (GenericTextStringElementHandler*)completedObject;
        return YES;
    }
    else if([withXmlElementName isEqualToString:kCustomIconUuidElementName]) {
        self.customIconUuid = (GenericTextUuidElementHandler*)completedObject;
        return YES;
    }
    
    return NO;
}

- (XmlTree *)generateXmlTree {
    XmlTree* ret = [[XmlTree alloc] initWithXmlElementName:kEntryElementName];
    
    ret.node = self.nonCustomisedXmlTree.node;
    
    if(self.uuid) [ret.children addObject:[self.uuid generateXmlTree]];
    if(self.times) [ret.children addObject:[self.times generateXmlTree]];
    
    if(self.iconId) [ret.children addObject:[self.iconId generateXmlTree]];
    if(self.customIconUuid) [ret.children addObject:[self.customIconUuid generateXmlTree]];
    
    for (NSString* key in self.strings.allKeys) {
        StringValue* value = self.strings[key];
        String* strXml = [[String alloc] initWithKey:key value:value.value protected:value.protected context:self.context];
        [ret.children addObject:[strXml generateXmlTree]];
    }

    for (Binary *binary in self.binaries) {
        [ret.children addObject:[binary generateXmlTree]];
    }
    
    // History...
    
    if(self.history && self.history.entries && self.history.entries.count) {
        [ret.children addObject:[self.history generateXmlTree]];
    }

    [ret.children addObjectsFromArray:self.nonCustomisedXmlTree.children];
    
    return ret;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Strings

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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Well Known Strings

- (NSString *)title {
    return [self getStringOrDefault:kTitleStringKey];
}

-(void)setTitle:(NSString *)title {
    [self setString:kTitleStringKey value:title protected:NO]; // FUTURE: Default Protection can be specified in the header
}

- (NSString *)username {
    return [self getStringOrDefault:kUserNameStringKey];
}

- (void)setUsername:(NSString *)username {
    [self setString:kUserNameStringKey value:username protected:NO];  // FUTURE: Default Protection can be specified in the header
}

- (NSString *)password {
    return [self getStringOrDefault:kPasswordStringKey];
}

- (void)setPassword:(NSString *)password {
    [self setString:kPasswordStringKey value:password protected:YES];  // FUTURE: Default Protection can be specified in the header
}

- (NSString *)url {
    return [self getStringOrDefault:kUrlStringKey];
}

- (void)setUrl:(NSString *)url {
    [self setString:kUrlStringKey value:url protected:NO];  // FUTURE: Default Protection can be specified in the header
}

- (NSString *)notes {
    return [self getStringOrDefault:kNotesStringKey];
}

- (void)setNotes:(NSString *)notes {
    [self setString:kNotesStringKey value:notes protected:NO];  // FUTURE: Default Protection can be specified in the header
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Custom Strings Readonly

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

- (NSNumber *)icon {
    return (self.iconId && self.iconId.text.length) ? @([self.iconId.text intValue]) : nil;
}

- (void)setIcon:(NSNumber *)icon {
    if(icon != nil) {
        if(!self.iconId) {
            self.iconId = [[GenericTextStringElementHandler alloc] initWithXmlElementName:kIconIdElementName context:self.context];
        }
        
        self.iconId.text = icon != nil ? icon.stringValue : nil;
    }
    else {
        self.iconId = nil;
    }
}

-(NSUUID *)customIcon {
    return self.customIconUuid ? self.customIconUuid.uuid : nil;
}

-(void)setCustomIcon:(NSUUID *)customIcon {
    if(!self.customIconUuid) {
        self.customIconUuid = [[GenericTextUuidElementHandler alloc] initWithXmlElementName:kCustomIconUuidElementName context:self.context];
    }
    
    self.customIconUuid.uuid = customIcon;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"[%@]-[%@]-[%@]-[%@]-[%@]\nUUID = [%@]\nTimes = [%@], iconId = [%@]/[%@]\ncustomFields = [%@]",
            self.title, self.username, self.password, self.url, self.notes, self.uuid, self.times, self.iconId, self.customIcon, self.customStrings];
}

@end
