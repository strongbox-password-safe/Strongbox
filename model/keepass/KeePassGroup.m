//
//  Group.m
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "KeePassGroup.h"
#import "KeePassDatabase.h"
#import "SimpleXmlValueExtractor.h"

@implementation KeePassGroup

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    if(self = [super initWithXmlElementName:kGroupElementName context:context]) {
        self.groups = [NSMutableArray array];
        self.entries = [NSMutableArray array];
        self.name = @"";
        self.uuid = NSUUID.UUID;
    }
    
    return self;
}

-(instancetype)initAsKeePassRoot:(XmlProcessingContext*)context {
    self = [self initWithContext:context];
    if (self) {
        self.name = kDefaultRootGroupName;
    }
    return self;
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
    if([xmlElementName isEqualToString:kGroupElementName]) {
        return [[KeePassGroup alloc] initWithContext:self.context];
    }
    else if([xmlElementName isEqualToString:kEntryElementName]) {
        return [[Entry alloc] initWithContext:self.context];
    }
    
    return [super getChildHandler:xmlElementName];
}

- (BOOL)addKnownChildObject:(id<XmlParsingDomainObject>)completedObject withXmlElementName:(NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kGroupElementName]) {
        [self.groups addObject:(KeePassGroup*)completedObject];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kNameElementName]) {
        self.name = [SimpleXmlValueExtractor getStringFromText:completedObject];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kUuidElementName]) {
        self.uuid = [SimpleXmlValueExtractor getUuid:completedObject];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kEntryElementName]) {
        [self.entries addObject:(Entry*)completedObject];
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
    
    return NO;
}

- (BOOL)writeXml:(id<IXmlSerializer>)serializer {
    if(![serializer beginElement:self.originalElementName
                            text:self.originalText
                      attributes:self.originalAttributes]) {
        return NO;
    }

    if (![serializer writeElement:kNameElementName text:self.name]) return NO;
    if (![serializer writeElement:kUuidElementName uuid:self.uuid]) return NO;
    if (self.icon && ![serializer writeElement:kIconIdElementName integer:self.icon.integerValue]) return NO;
    if (self.customIcon && ![serializer writeElement:kCustomIconUuidElementName uuid:self.customIcon]) return NO;

    if(self.groups) {
        for (KeePassGroup *group in self.groups) {
            if(![group writeXml:serializer]) {
                return NO;
            }
        }
    }
    
    if(self.entries) {
        for (Entry *entry in self.entries) {
            if(![entry writeXml:serializer]) {
                return NO;
            }
        }
    }
    
    if(![super writeUnmanagedChildren:serializer]) {
        return NO;
    }
    
    [serializer endElement];
    
    return YES;
}

- (BOOL)isEqual:(id)object {
    if (object == nil) {
        return NO;
    }
    
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[KeePassGroup class]]) {
        return NO;
    }
    
    KeePassGroup* other = (KeePassGroup*)object;
    if (![self.name isEqualToString:other.name]) {
        return NO;
    }
    if (![self.uuid isEqual:other.uuid]) {
        return NO;
    }
    if (!(self.icon == nil && other.icon == nil) && ![self.icon isEqual:other.icon]) {
        return NO;
    }
    if (!(self.customIcon == nil && other.customIcon == nil) && ![self.customIcon isEqual:other.customIcon]) {
        return NO;
    }
    if(self.entries.count != other.entries.count) {
        return NO;
    }
    if(self.groups.count != other.groups.count) {
        return NO;
    }

    for (int i=0; i < self.groups.count; i++) {
        KeePassGroup* a = self.groups[i];
        KeePassGroup* b = other.groups[i];
        if(![a isEqual:b]) {
            return NO;
        }
    }

    for (int i=0; i < self.entries.count; i++) {
        Entry* a = self.entries[i];
        Entry* b = other.entries[i];
        if(![a isEqual:b]) {
            return NO;
        }
    }
    
    return YES;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Name = [%@], Entries = [%@], Groups = [%@], iconId=[%@]/[%@]\nUUID = [%@]", self.name, self.entries, self.groups, self.icon, self.customIcon, self.uuid];
}

@end
