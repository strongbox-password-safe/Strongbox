//
//  SafeItemViewModel.m
//  StrongBox
//
//  Created by Mark on 23/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "SafeItemViewModel.h"

@implementation SafeItemViewModel {
    Group *_group;
    Record *_record;
    BOOL _isGroup;
}

- (instancetype)initAsRootGroup {
    return [self initWithGroup:[[Group alloc] initAsRootGroup]];
}

- (instancetype)initWithGroup:(Group *)group {
    if(self = [super init]) {
        _group = group;
        _isGroup = YES;
    }
    
    return self;
}

- (instancetype)initWithRecord:(Record *)record {
    if(self = [super init]) {
        _record = record;
        _isGroup = NO;
    }
    
    return self;
}

- (NSString *)title {
    return _isGroup ? _group.title : _record.title;
}

- (NSString *)password {
    return _record.password;
}

- (NSString *)username {
    return _record.username;
}

- (NSString *)url {
    return _record.url;
}

- (NSString *)notes {
    return _record.notes;
}

- (NSString *)groupPathPrefix {
    if(!self.isGroup) {
        return nil;
    }
    
    else if (_group.isRootGroup) {
        return @"";
    }
    
    NSArray *prefixComponents = [_group.pathComponents subarrayWithRange:NSMakeRange(0, _group.pathComponents.count - 1)];

    return [prefixComponents componentsJoinedByString:@"/"];
}

- (Group *)group {
    return _group;
}

- (Record *)record {
    return _record;
}

- (BOOL)isRootGroup {
    return self.isGroup && self.group.isRootGroup;
}

- (SafeItemViewModel*)getParentGroup {
    return self.isGroup ? [[SafeItemViewModel alloc] initWithGroup:[self.group getParentGroup]] :
    [[SafeItemViewModel alloc] initWithGroup:self.record.group];
}

- (BOOL)isEqualToSafeItemViewModel:(SafeItemViewModel *)item {
    if (!item) {
        return NO;
    }

    if (item.isGroup != self.isGroup) {
        return NO;
    }

    if (item.isGroup) {
        return [item.group isEqual:self.group];
    }

    if (item.record.uuid && self.record.uuid) {
        return [item.record.uuid isEqualToString:self.record.uuid];
    }
    
    BOOL haveEqualGroups = (!self.record.group && !item.record.group) || [self.record.group isEqual:item.record.group];

    if (!haveEqualGroups) {
        return NO;
    }

    BOOL haveEqualTitles = (!self.title && !item.title) || [self.title isEqualToString:item.title];
    BOOL haveEqualPasswords = (!self.password && !item.password) || [self.password isEqualToString:item.password];
    BOOL haveEqualUsernames = (!self.username && !item.username) || [self.username isEqualToString:item.username];
    BOOL haveEqualUrls = (!self.url && !item.url) || [self.url isEqualToString:item.url];
    BOOL haveEqualNotes = (!self.notes && !item.notes) || [self.notes isEqualToString:item.notes];

    return haveEqualTitles && haveEqualPasswords && haveEqualUsernames && haveEqualUrls && haveEqualNotes;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object {
    if(!object) {
        return NO;
    }
        
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[SafeItemViewModel class]]) {
        return NO;
    }

    return [self isEqualToSafeItemViewModel:(SafeItemViewModel *)object];
}

- (NSUInteger)hash {
    if (self.isGroup) {
        return self.group.hash;
    }
    else {
        return self.record.uuid ?
            (self.record.uuid).hash :
            (self.title).hash ^ (self.password).hash ^ (self.username).hash ^ (self.url).hash ^ (self.notes).hash;
    }
}

- (NSString*)description {
    return [NSString stringWithFormat:self.isGroup ? @"[Group] -> [%@]" : @"[Record] -> [%@]",
            self.isGroup ? (self.isRootGroup ? @"<Root Group>" : self.title) : self.title];
}

@end
