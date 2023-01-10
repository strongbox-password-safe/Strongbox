//
//  Group.m
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "KeePassGroup.h"
#import "KeePassDatabase.h"
#import "SimpleXmlValueExtractor.h"
#import "CustomData.h"
#import "NSUUID+Zero.h"
#import "NSArray+Extensions.h"
#import "Utils.h"

@implementation KeePassGroup

- (BOOL)isGroup {
    return YES;
}

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    if(self = [super initWithXmlElementName:kGroupElementName context:context]) {
        self.groupsAndEntries = [NSMutableArray array];
        self.name = @"";
        self.uuid = NSUUID.UUID;
        self.times = [[Times alloc] initWithXmlElementName:kTimesElementName context:context];
        self.notes = nil;
        self.customData = [[CustomData alloc] initWithContext:context];
        self.defaultAutoTypeSequence = nil;
        self.enableAutoType = nil;
        self.enableSearching = nil;
        self.lastTopVisibleEntry = nil;
        self.tags = [NSMutableSet set];
        self.isExpanded = YES;
    }
    
    return self;
}

- (instancetype)initAsKeePassRoot:(XmlProcessingContext*)context {
    self = [self initWithContext:context];
    if (self) {
        NSString *rootGroupName = NSLocalizedString(@"generic_database", @"Database");
        if ([rootGroupName isEqualToString:@"generic_database"]) { 
            rootGroupName = kDefaultRootGroupName;
        }
        self.name = rootGroupName;
    }
    return self;
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
    if([xmlElementName isEqualToString:kGroupElementName]) {
        return [[KeePassGroup alloc] initWithContext:self.context];
    }
    if([xmlElementName isEqualToString:kTimesElementName]) {
        return [[Times alloc] initWithContext:self.context];
    }
    else if([xmlElementName isEqualToString:kEntryElementName]) {
        return [[Entry alloc] initWithContext:self.context];
    }
    else if ([xmlElementName isEqualToString:kCustomDataElementName]) {
        return [[CustomData alloc] initWithContext:self.context];
    }

    return [super getChildHandler:xmlElementName];
}

- (BOOL)addKnownChildObject:(id<XmlParsingDomainObject>)completedObject withXmlElementName:(NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kGroupElementName]) {
        [self.groupsAndEntries addObject:(KeePassGroup*)completedObject];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kEntryElementName]) {
        [self.groupsAndEntries addObject:(Entry*)completedObject];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kTimesElementName]) {
        self.times = (Times*)completedObject;
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
    else if([withXmlElementName isEqualToString:kIconIdElementName]) {
        self.icon = [SimpleXmlValueExtractor getNumber:completedObject];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kCustomIconUuidElementName]) {
        self.customIcon = [SimpleXmlValueExtractor getUuid:completedObject];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kCustomDataElementName]) {
        self.customData = (CustomData*)completedObject;
        return YES;
    }
    else if([withXmlElementName isEqualToString:kNotesElementName]) {
        self.notes = [SimpleXmlValueExtractor getStringFromText:completedObject];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kDefaultAutoTypeSequenceElementName]) {
        self.defaultAutoTypeSequence = [SimpleXmlValueExtractor getStringFromText:completedObject];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kEnableAutoTypeElementName]) {
        self.enableAutoType = [SimpleXmlValueExtractor getOptionalBool:completedObject];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kEnableSearchingElementName]) {
        self.enableSearching = [SimpleXmlValueExtractor getOptionalBool:completedObject];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kLastTopVisibleElementName]) {
        self.lastTopVisibleEntry = [SimpleXmlValueExtractor getUuid:completedObject];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kTagsElementName]) {
        NSString* tagsString = [SimpleXmlValueExtractor getStringFromText:completedObject];
        

        
        NSArray<NSString*>* tags = [Utils getTagsFromTagString:tagsString];
        
        [self.tags addObjectsFromArray:tags];
        
        return YES;
    }
    else if ( [withXmlElementName isEqualToString:kIsExpandedElementName] ) {
        self.isExpanded = [SimpleXmlValueExtractor getBool:completedObject defaultValue:YES];
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

        if (![serializer writeElement:kNameElementName text:self.name]) return NO;
        if (![serializer writeElement:kUuidElementName uuid:self.uuid]) return NO;
        if (self.icon && ![serializer writeElement:kIconIdElementName integer:self.icon.integerValue]) return NO;
        if (self.customIcon && ![serializer writeElement:kCustomIconUuidElementName uuid:self.customIcon]) return NO;

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
        
        if ( !self.isExpanded ) { 
            if ( ![serializer writeElement:kIsExpandedElementName boolean:NO]) return NO;
        }
        
        if (self.groupsAndEntries) {
            for (id<KeePassGroupOrEntry> groupOrEntry in self.groupsAndEntries) {
                BaseXmlDomainObjectHandler *handler = (BaseXmlDomainObjectHandler*)groupOrEntry;
                if(![handler writeXml:serializer]) {
                    return NO;
                }
            }
        }

        if (self.customData && self.customData.dictionary.count) {
            if ( ![self.customData writeXml:serializer] ) return NO;
        }

        if (self.notes.length) {
            if (![serializer writeElement:kNotesElementName text:self.notes]) return NO;
        }

        if ( self.defaultAutoTypeSequence.length ) {
            if ( ![serializer writeElement:kDefaultAutoTypeSequenceElementName text:self.defaultAutoTypeSequence] ) return NO;
        }
        
        if ( self.enableAutoType != nil ) {
            if ( ![serializer writeElement:kEnableAutoTypeElementName boolean:self.enableAutoType.boolValue]) return NO;
        }
        
        if ( self.enableSearching != nil ) {
            if ( ![serializer writeElement:kEnableSearchingElementName boolean:self.enableSearching.boolValue]) return NO;
        }
        
        if ( self.lastTopVisibleEntry && ![self.lastTopVisibleEntry isEqual:NSUUID.zero]) {
            if ( ![serializer writeElement:kLastTopVisibleElementName uuid:self.lastTopVisibleEntry]) return NO;
        }
        
        if ( self.previousParentGroup ) {
            if ( ![serializer writeElement:kPreviousParentGroupElementName uuid:self.previousParentGroup]) return NO;
        }
        
        if( ![super writeUnmanagedChildren:serializer]) {
            return NO;
        }
        
        [serializer endElement];
        
        return YES;
    }
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
    if (![self.times isEqual:other.times]) {
        return NO;
    }
    if (![self.tags isEqualToSet:other.tags]) {
        return NO;
    }
    
    if ( self.isExpanded != other.isExpanded ) {
        return NO;
    }
    
    if (![self.customData isEqual:other.customData]) {
        return NO;
    }
    
    if ( self.notes.length && other.notes.length && ![self.notes isEqualToString:other.notes] ) {
        return NO;
    }
    
    if ( self.defaultAutoTypeSequence.length && other.defaultAutoTypeSequence.length && ![self.defaultAutoTypeSequence isEqualToString:other.defaultAutoTypeSequence] ) {
        return NO;
    }

    if ( !(self.enableAutoType == nil && other.enableAutoType == nil) && self.enableAutoType.boolValue != other.enableAutoType.boolValue ) {
        return NO;
    }
    if ( !(self.enableSearching == nil && other.enableSearching == nil) && self.enableSearching.boolValue != other.enableSearching.boolValue ) {
        return NO;
    }
        
    if ( !(self.lastTopVisibleEntry == nil && other.lastTopVisibleEntry == nil) && ![self.lastTopVisibleEntry isEqual:other.lastTopVisibleEntry] ) {
        return NO;
    }

    if ((self.previousParentGroup == nil && other.previousParentGroup != nil) || (self.previousParentGroup != nil && ![self.previousParentGroup isEqual:other.previousParentGroup] )) {
        return NO;
    }

    
    
    if (self.groupsAndEntries.count != other.groupsAndEntries.count) {
        return NO;
    }

    for (int i=0; i < self.groupsAndEntries.count; i++) {
        id<KeePassGroupOrEntry> a = self.groupsAndEntries[i];
        id<KeePassGroupOrEntry> b = other.groupsAndEntries[i];
        
        if(![a isEqual:b]) {
            return NO;
        }
    }
        
    return YES;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Name = [%@], Notes = [%@], Children = [%@], Times = [%@], iconId=[%@]/[%@]\nUUID = [%@]", self.name, self.notes, self.groupsAndEntries, self.times, self.icon, self.customIcon, self.uuid];
}

@end
