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

- (instancetype)init {
    if(self = [super initWithXmlElementName:kEntryElementName]) {
        self.uuid = [[GenericTextUuidElementHandler alloc] initWithXmlElementName:kUuidElementName];
        self.times = [[Times alloc] initWithXmlElementName:kTimesElementName];
        self.strings = [NSMutableArray array];
    }
    
    return self;
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
    if([xmlElementName isEqualToString:kUuidElementName]) {
        return [[GenericTextUuidElementHandler alloc] initWithXmlElementName:kUuidElementName];
    }
    else if([xmlElementName isEqualToString:kTimesElementName]) {
        return [[Times alloc] init];
    }
    else if([xmlElementName isEqualToString:kStringElementName]) {
        return [[String alloc] init];
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
    
    return NO;
}

- (XmlTree *)generateXmlTree {
    XmlTree* ret = [[XmlTree alloc] initWithXmlElementName:kEntryElementName];
    
    ret.node = self.nonCustomisedXmlTree.node;
    
    [ret.children addObject:[self.uuid generateXmlTree]];
    [ret.children addObject:[self.times generateXmlTree]];
    
    for (String *string in self.strings) {
        [ret.children addObject:[string generateXmlTree]];
    }
    
    [ret.children addObjectsFromArray:self.nonCustomisedXmlTree.children];
    
    return ret;
}

// TODO: perf?
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
    BOOL protected = NO; // TODO: init this class with the defaults
    [self setString:kTitleStringKey value:title protected:protected];
}

- (NSString *)username {
    String* string = [[self stringsLookup] objectForKey:kUserNameStringKey];
    return string == nil ? @"" : string.value.text;
}

- (void)setUsername:(NSString *)username {
    BOOL protected = NO; // TODO: init this class with the defaults
    [self setString:kUserNameStringKey value:username protected:protected];
}

- (NSString *)password {
    String* string = [[self stringsLookup] objectForKey:kPasswordStringKey];
    return string == nil ? @"" : string.value.text;
}

- (void)setPassword:(NSString *)password {
    BOOL protected = YES; // TODO: init this class with the defaults
    [self setString:kPasswordStringKey value:password protected:protected];
}

- (NSString *)url {
    String* string = [[self stringsLookup] objectForKey:kUrlStringKey];
    return string == nil ? @"" : string.value.text;
}

- (void)setUrl:(NSString *)url {
    BOOL protected = NO; // TODO: init this class with the defaults
    [self setString:kUrlStringKey value:url protected:protected];
}

- (NSString *)notes {
    String* string = [[self stringsLookup] objectForKey:kNotesStringKey];
    return string == nil ? @"" : string.value.text;
}

- (void)setNotes:(NSString *)notes {
    BOOL protected = NO; // TODO: init this class with the defaults
    [self setString:kNotesStringKey value:notes protected:protected];
}

- (void)setString:(NSString*)key value:(NSString*)value protected:(BOOL)protected {
    String* string = [[self stringsLookup] objectForKey:key];
    
    if(!string) {
        string = [[String alloc] initWithProtectedValue:protected];
        string.key.text = key;
        string.value.text = value ? value : @""; // TODO: Test Nil;
        
        [self.strings addObject:string];
    }
    else {
        string.value.text = value ? value : @""; // TODO: Test Nil;
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

- (NSString *)description {
    return [NSString stringWithFormat:@"[%@]-[%@]-[%@]-[%@]-[%@]\nUUID = [%@]\nTimes = [%@]\ncustomFields = [%@]",
            self.title, self.username, self.password, self.url, self.notes, self.uuid, self.times, self.customFields];
}

@end
