//
//  FastMaps.m
//  MacBox
//
//  Created by Strongbox on 09/03/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import "FastMaps.h"

@implementation FastMaps

- (instancetype)initWithUuidMap:(NSDictionary<NSUUID *,Node *> *)uuidMap
                withExpiryDates:(NSSet<NSUUID *> *)withExpiryDates
                withAttachments:(NSSet<NSUUID *> *)withAttachments
            withKeeAgentSshKeys:(NSSet<NSUUID *> *)withKeeAgentSshKeys
                   withPasskeys:(NSSet<NSUUID *> *)withPasskeys 
                      withTotps:(NSSet<NSUUID *> *)withTotps
                         tagMap:(NSDictionary<NSString *,NSSet<NSUUID *> *> *)tagMap
                    usernameSet:(NSCountedSet<NSString *> *)usernameSet
                       emailSet:(NSCountedSet<NSString *> *)emailSet
                         urlSet:(NSCountedSet<NSString *> *)urlSet
              customFieldKeySet:(NSCountedSet<NSString *> *)customFieldKeySet
                entryTotalCount:(NSInteger)entryTotalCount 
                groupTotalCount:(NSInteger)groupTotalCount
              excludedFromAudit:(NSSet<NSUUID *> *)excludedFromAudit {
    if (self = [super init]) {
        _uuidMap = [uuidMap copy];
        _withExpiryDates = [withExpiryDates copy];
        _withAttachments = [withAttachments copy];
        _withKeeAgentSshKeys = [withKeeAgentSshKeys copy];
        _withPasskeys = [withPasskeys copy];
        _withTotps = [withTotps copy];
        _tagMap = [tagMap copy];
        
        
        
        _usernameSet = usernameSet;
        _emailSet = emailSet;
        _urlSet = urlSet;
        _customFieldKeySet = customFieldKeySet;
        _entryTotalCount = entryTotalCount;
        _groupTotalCount = groupTotalCount;
        _excludedFromAudit = excludedFromAudit;
    }
    
    return self;
}

@end
