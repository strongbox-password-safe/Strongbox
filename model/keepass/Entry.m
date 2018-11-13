//
//  Entry.m
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "Entry.h"
#import "KeePassDatabase.h"

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

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    if(self = [super initWithXmlElementName:kEntryElementName context:context]) {
        self.uuid = [[GenericTextUuidElementHandler alloc] initWithXmlElementName:kUuidElementName context:context];
        self.times = [[Times alloc] initWithXmlElementName:kTimesElementName context:context];
        self.strings = [NSMutableArray array];
        self.binaries = [NSMutableArray array];
        self.iconId = nil; //[[GenericTextStringElementHandler alloc] initWithXmlElementName:kIconIdElementName context:context];
        self.customIconUuid = nil; //[[GenericTextUuidElementHandler alloc] initWithXmlElementName:kCustomIconUuid context:context];
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
    else if([withXmlElementName isEqualToString:kStringElementName]) {
        [self.strings addObject:(String*)completedObject];
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
    
    [ret.children addObject:[self.uuid generateXmlTree]];
    [ret.children addObject:[self.times generateXmlTree]];
    
    if(self.iconId) [ret.children addObject:[self.iconId generateXmlTree]];
    if(self.customIconUuid) [ret.children addObject:[self.customIconUuid generateXmlTree]];
    
    for (String *string in self.strings) {
        [ret.children addObject:[string generateXmlTree]];
    }

    for (Binary *binary in self.binaries) {
        [ret.children addObject:[binary generateXmlTree]];
    }
    
    [ret.children addObjectsFromArray:self.nonCustomisedXmlTree.children];
    
    return ret;
}

- (NSDictionary<NSString*, String*>*)stringsLookup {
    NSMutableDictionary<NSString*, String*> *ret = [NSMutableDictionary dictionary];

    for (String* string in self.strings) {
        [ret setObject:string forKey:string.key.text];
    }
    
    return ret;
}

- (NSString *)title {
    String* string = [[self stringsLookup] objectForKey:kTitleStringKey];
    return string == nil ? @"" : string.value.text;
}

-(void)setTitle:(NSString *)title {
    BOOL protected = NO;
    [self setString:kTitleStringKey value:title protected:protected];
}

- (NSString *)username {
    String* string = [[self stringsLookup] objectForKey:kUserNameStringKey];
    return string == nil ? @"" : string.value.text;
}

- (void)setUsername:(NSString *)username {
    BOOL protected = NO;
    [self setString:kUserNameStringKey value:username protected:protected];
}

- (NSString *)password {
    String* string = [[self stringsLookup] objectForKey:kPasswordStringKey];
    return string == nil ? @"" : string.value.text;
}

- (void)setPassword:(NSString *)password {
    BOOL protected = YES; // FUTURE: init this with the defaults if they are in the XML Doc?
    [self setString:kPasswordStringKey value:password protected:protected];
}

- (NSString *)url {
    String* string = [[self stringsLookup] objectForKey:kUrlStringKey];
    return string == nil ? @"" : string.value.text;
}

- (void)setUrl:(NSString *)url {
    BOOL protected = NO;
    [self setString:kUrlStringKey value:url protected:protected];
}

- (NSString *)notes {
    String* string = [[self stringsLookup] objectForKey:kNotesStringKey];
    return string == nil ? @"" : string.value.text;
}

- (void)setNotes:(NSString *)notes {
    BOOL protected = NO;
    [self setString:kNotesStringKey value:notes protected:protected];
}

- (void)setString:(NSString*)key value:(NSString*)value protected:(BOOL)protected {
    String* string = [[self stringsLookup] objectForKey:key];
    
    if(!string) {
        string = [[String alloc] initWithProtectedValue:protected context:self.context];
        string.key.text = key;
        string.value.text = value ? value : @"";
        
        [self.strings addObject:string];
    }
    else {
        string.value.text = value ? value : @"";
    }
}

-(NSDictionary<NSString *,NSString *> *)customFields {
    NSMutableDictionary<NSString*, NSString*> *ret = [NSMutableDictionary dictionary];
    
    for (String* string in self.strings) {
        if(![wellKnownKeys containsObject:string.key.text]) {
            [ret setObject:string.value.text forKey:string.key.text];
        }
    }
    
    return [ret copy];
}

- (NSNumber *)icon {
    return (self.iconId && self.iconId.text.length) ? @([self.iconId.text intValue]) : nil;
}

- (void)setIcon:(NSNumber *)icon {
    if(icon) {
        if(!self.iconId) {
            self.iconId = [[GenericTextStringElementHandler alloc] initWithXmlElementName:kIconIdElementName context:self.context];
        }
        
        self.iconId.text = icon ? icon.stringValue : nil;
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
            self.title, self.username, self.password, self.url, self.notes, self.uuid, self.times, self.iconId, self.customIcon, self.customFields];
}

@end
