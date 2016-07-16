//
//  SafeItemViewModel.m
//  StrongBox
//
//  Created by Mark on 23/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "SafeItemViewModel.h"

@implementation SafeItemViewModel
{
    Group*     _group;
    Record*    _record;
    BOOL       _isGroup;
}

-(id)initWithGroup:(Group*)group
{
    _group = group;
    _isGroup = YES;
    
    return self;
}

-(id)initWithRecord:(Record*)record
{
    _record = record;
    _isGroup = NO;
    
    return self;
}

-(NSString*)  title
{
    return _isGroup ? _group.suffixDisplayString : _record.title;
}

-(void) setTitle:(NSString *)title
{
    if(_isGroup){
        //print("Cannot rename group like this, use CoreModel.renameItem!");
    }else{
        _record.title = title;
    }
}

-(NSString*)  password
{
    return _record.password;
}

-(void) setPassword:(NSString *)password{
    _record.password = password;
}

-(NSString*)  username
{
    return _record.username;
}

-(void)setUsername:(NSString *)username
{
    _record.username = username;
}

-(NSString*)  url
{
    return _record.url;
}

-(void) setUrl:(NSString *)url{
    _record.url = url;
}

-(NSString*)  notes
{
    return _record.notes;
}

-(void) setNotes:(NSString *)notes{
    _record.notes = notes;
}

-(NSString*) groupPathPrefix
{
    return _group.pathPrefixDisplayString;
}

-(Group*) group
{
    return _group;
}

-(Record*) record
{
    return _record;
}

- (BOOL)isEqualToSafeItemViewModel:(SafeItemViewModel *)item {
    if (!item) {
        return NO;
    }
    
    if(item.isGroup != self.isGroup){
        return NO;
    }
    
    if(item.isGroup){
        return [item.group isSameGroupAs:self.group];
    }
    
    if(item.record.uuid && self.record.uuid){
        return [item.record.uuid isEqualToString:self.record.uuid];
    }

    BOOL haveEqualGroups =(!self.record.group && !item.record.group) || [self.record.group isSameGroupAs:item.record.group];
    if(!haveEqualGroups){
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
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[SafeItemViewModel class]]) {
        return NO;
    }
    
    return [self isEqualToSafeItemViewModel:(SafeItemViewModel *)object];
}

- (NSUInteger)hash {
    if(self.isGroup){
        return [[self.group fullPath] hash];
    }
    else{
        return [self.title hash] ^ [self.password hash] ^ [self.username hash] ^ [self.url hash] ^ [self.notes hash];
    }
}

@end
