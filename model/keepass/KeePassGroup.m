//
//  Group.m
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "KeePassGroup.h"
#import "KeePassDatabase.h"

@implementation KeePassGroup

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    if(self = [super initWithXmlElementName:kGroupElementName context:context]) {
        self.groups = [NSMutableArray array];
        self.entries = [NSMutableArray array];
        self.name = [[GenericTextStringElementHandler alloc] initWithXmlElementName:kNameElementName context:context];
        self.uuid = [[GenericTextUuidElementHandler alloc] initWithXmlElementName:kUuidElementName context:context];
        self.iconId = nil; // [[GenericTextStringElementHandler alloc] initWithXmlElementName:kIconIdElementName context:context];
        self.customIconUuid = nil; //[[GenericTextUuidElementHandler alloc] initWithXmlElementName:kCustomIconUuid context:context];
    }
    
    return self;
}

-(instancetype)initAsKeePassRoot:(XmlProcessingContext*)context {
    self = [self initWithContext:context];
    if (self) {
        self.name.text = kDefaultRootGroupName;
    }
    return self;
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
    if([xmlElementName isEqualToString:kGroupElementName]) {
        return [[KeePassGroup alloc] initWithContext:self.context];
    }
    else if([xmlElementName isEqualToString:kNameElementName]) {
        return [[GenericTextStringElementHandler alloc] initWithXmlElementName:kNameElementName context:self.context];
    }
    else if([xmlElementName isEqualToString:kUuidElementName]) {
        return [[GenericTextUuidElementHandler alloc] initWithXmlElementName:kUuidElementName context:self.context];
    }
    else if([xmlElementName isEqualToString:kEntryElementName]) {
        return [[Entry alloc] initWithContext:self.context];
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
    if([withXmlElementName isEqualToString:kGroupElementName]) {
        [self.groups addObject:(KeePassGroup*)completedObject];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kNameElementName]) {
        self.name = (GenericTextStringElementHandler*)completedObject;
        return YES;
    }
    else if([withXmlElementName isEqualToString:kUuidElementName]) {
        self.uuid = (GenericTextUuidElementHandler*)completedObject;
        return YES;
    }
    else if([withXmlElementName isEqualToString:kEntryElementName]) {
        [self.entries addObject:(Entry*)completedObject];
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
    XmlTree* ret = [[XmlTree alloc] initWithXmlElementName:kGroupElementName];
    
    ret.node = self.nonCustomisedXmlTree.node;
    
    [ret.children addObject:[self.uuid generateXmlTree]];
    [ret.children addObject:[self.name generateXmlTree]];
    
    if(self.iconId) [ret.children addObject:[self.iconId generateXmlTree]];
    if(self.customIconUuid) [ret.children addObject:[self.customIconUuid generateXmlTree]];

    // To Try make comparison of XML easier
    
    NSArray<KeePassGroup*>* sortedByName = [self.groups sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [((KeePassGroup*)obj1).uuid.uuid.UUIDString compare:((KeePassGroup*)obj2).uuid.uuid.UUIDString];
    }];
    
    for (KeePassGroup *group in sortedByName) {
        [ret.children addObject:[group generateXmlTree]];
    }
    
    NSArray<Entry*>* entriesSortedByName = [self.entries sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [((Entry*)obj1).uuid.uuid.UUIDString compare:((Entry*)obj2).uuid.uuid.UUIDString];
    }];
    
    for (Entry *entry in entriesSortedByName) {
        [ret.children addObject:[entry generateXmlTree]];
    }
    
    [ret.children addObjectsFromArray:self.nonCustomisedXmlTree.children];
    
    return ret;
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
    return [NSString stringWithFormat:@"Name = [%@], Entries = [%@], Groups = [%@], iconId=[%@]/[%@]\nUUID = [%@]", self.name, self.entries, self.groups, self.iconId, self.customIcon, self.uuid];
}

@end
