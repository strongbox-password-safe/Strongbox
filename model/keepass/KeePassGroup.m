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

- (instancetype)init {
    if(self = [super initWithXmlElementName:kGroupElementName]) {
        self.groups = [NSMutableArray array];
        self.entries = [NSMutableArray array];
        self.name = [[GenericTextStringElementHandler alloc] initWithXmlElementName:kNameElementName];
        self.uuid = [[GenericTextUuidElementHandler alloc] initWithXmlElementName:kUuidElementName];
    }
    
    return self;
}

-(instancetype)initAsKeePassRoot {
    self = [self init];
    if (self) {
        self.name.text = kDefaultRootGroupName;
    }
    return self;
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
    if([xmlElementName isEqualToString:kGroupElementName]) {
        return [[KeePassGroup alloc] init];
    }
    else if([xmlElementName isEqualToString:kNameElementName]) {
        return [[GenericTextStringElementHandler alloc] initWithXmlElementName:kNameElementName];
    }
    else if([xmlElementName isEqualToString:kUuidElementName]) {
        return [[GenericTextUuidElementHandler alloc] initWithXmlElementName:kUuidElementName];
    }
    else if([xmlElementName isEqualToString:kEntryElementName]) {
        return [[Entry alloc] init];
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
    if([withXmlElementName isEqualToString:kEntryElementName]) {
        [self.entries addObject:(Entry*)completedObject];
        return YES;
    }
    
    return NO;
}

- (XmlTree *)generateXmlTree {
    XmlTree* ret = [[XmlTree alloc] initWithXmlElementName:kGroupElementName];
    
    ret.node = self.nonCustomisedXmlTree.node;
    
    [ret.children addObject:[self.uuid generateXmlTree]];
    [ret.children addObject:[self.name generateXmlTree]];
    
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

- (NSString *)description {
    return [NSString stringWithFormat:@"Name = [%@], Entries = [%@], Groups = [%@]\nUUID = [%@]", self.name, self.entries, self.groups, self.uuid];
}

@end
