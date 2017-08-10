//
//  CoreModel.m
//
//
//  Created by Mark on 01/09/2015.
//
//

#import <Foundation/Foundation.h>
#import "CoreModel.h"

//////////////////////////////////////////////////////////////////////////////////////////////////////
// Search


@interface CoreModel ()

@end

@implementation CoreModel

- (instancetype)initNewWithPassword:(NSString *)password {
    SafeDatabase* db = [[SafeDatabase alloc] initNewWithPassword:password];
    
    return [self initWithSafeDatabase:db];
}

- (instancetype)initExistingWithDataAndPassword:(NSData *)data password:(NSString *)password error:(NSError **)ppError {
    SafeDatabase* db = [[SafeDatabase alloc] initExistingWithData:password data:data error:ppError];
    
    if(db == nil) {
        return nil;
    }
    
    return [self initWithSafeDatabase:db];
}

- (instancetype)initWithSafeDatabase:(SafeDatabase *)safe {
    if (self = [super init]) {
        _safe = safe;
        return self;
    }
    else {
        return nil;
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (SafeItemViewModel *)addSubgroupWithUIString:(Group *)parentGroup title:(NSString *)title {
    Group *newGroup = [_safe addSubgroupWithUIString:parentGroup title:title];

    if (newGroup != nil) {
        return [[SafeItemViewModel alloc] initWithGroup:newGroup];
    }

    return nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSArray *)getSearchableItems {
    NSArray *records = [self.safe getAllRecords];
    NSArray *allDisplayableGroups = [self getAllDisplayableGroups:nil];

    NSMutableArray *items = [[NSMutableArray alloc] initWithCapacity:records.count + allDisplayableGroups.count];

    for (Group *group in allDisplayableGroups) {
        //NSLog(@"Adding %@ in %@", group.suffixDisplayString, group.pathPrefixDisplayString);

        [items addObject:[[SafeItemViewModel alloc] initWithGroup:group]];
    }

    for (Record *record in records) {
        [items addObject:[[SafeItemViewModel alloc] initWithRecord:record]];
    }

    return items;
}

- (NSArray *)getAllDisplayableGroups:(Group *)root {
    NSMutableArray *allDisplayableGroups = [[NSMutableArray alloc] init];

    NSArray *groupsForThisLevel = [self.safe getSubgroupsForGroup:root withFilter:nil deepSearch:NO];

    [allDisplayableGroups addObjectsFromArray:groupsForThisLevel];

    for (Group *group in groupsForThisLevel) {
        [allDisplayableGroups addObjectsFromArray:[self getAllDisplayableGroups:group]];
    }

    return allDisplayableGroups;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////
// Regular Displayable Items

- (NSArray<SafeItemViewModel*> *)getSubgroupsForGroup:(Group *)group {
    NSMutableArray *items = [[NSMutableArray alloc] init];

    NSMutableArray *subgroupsForCurrentGroup = [[NSMutableArray alloc] initWithArray:
                                                [self.safe getSubgroupsForGroup:group
                                                                     withFilter:nil
                                                                     deepSearch:NO]];

    [subgroupsForCurrentGroup sortUsingComparator:^(id obj1, id obj2) {
                                  NSString *s1 = ((Group *)obj1).suffixDisplayString;
                                  NSString *s2 = ((Group *)obj2).suffixDisplayString;
                                  return [s1 caseInsensitiveCompare:s2];
                              }];

    for (Group *grp in subgroupsForCurrentGroup) {
        [items addObject:[[SafeItemViewModel alloc] initWithGroup:grp]];
    }

    return items;
}

- (NSArray<SafeItemViewModel*> *)getItemsForGroup:(Group *)group {
    return [self getItemsForGroup:group withFilter:[[NSString alloc] init] deepSearch:NO];
}

- (NSArray<SafeItemViewModel*>  *)getItemsForGroup:(Group *)group
                   withFilter:(NSString *)filter {
    return [self getItemsForGroup:group withFilter:filter deepSearch:NO];
}

- (NSArray<SafeItemViewModel*>  *)getItemsForGroup:(Group *)group
                   withFilter:(NSString *)filter
                   deepSearch:(BOOL)deepSearch {
    NSMutableArray *items = [[NSMutableArray alloc] init];

    NSMutableArray *subgroupsForCurrentGroup = [[NSMutableArray alloc] initWithArray:
                                                [self.safe getSubgroupsForGroup:group
                                                                     withFilter:filter
                                                                     deepSearch:deepSearch]];

    [subgroupsForCurrentGroup sortUsingComparator:^(id obj1, id obj2) {
                                  NSString *s1 = ((Group *)obj1).suffixDisplayString;
                                  NSString *s2 = ((Group *)obj2).suffixDisplayString;
                                  return [s1 caseInsensitiveCompare:s2];
                              }];

    NSMutableArray *recordsForCurrentGroup = [[NSMutableArray alloc] initWithArray:[                                                                                    self.safe getRecordsForGroup:group withFilter:filter deepSearch:deepSearch]];

    [recordsForCurrentGroup sortUsingComparator:^(id obj1, id obj2) {
                                NSString *s1 = ((Record *)obj1).title;
                                NSString *s2 = ((Record *)obj2).title;
                                return [s1 caseInsensitiveCompare:s2];
                            }];

    for (Group *grp in subgroupsForCurrentGroup) {
        [items addObject:[[SafeItemViewModel alloc] initWithGroup:grp]];
    }

    for (Record *record in recordsForCurrentGroup) {
        [items addObject:[[SafeItemViewModel alloc] initWithRecord:record]];
    }

    return items;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)validateMoveItems:(NSArray *)items destination:(Group *)group {
    return [self validateMoveItems:items destination:group checkIfMoveIntoSubgroupOfDestinationOk:NO];
}

- (BOOL)validateMoveItems:(NSArray *)items destination:(Group *)group checkIfMoveIntoSubgroupOfDestinationOk:(BOOL)checkIfMoveIntoSubgroupOfDestinationOk {
    BOOL directMove = [self moveOrValidateItems:items destination:group validate:YES];

    if (!directMove && checkIfMoveIntoSubgroupOfDestinationOk) {
        NSArray *subGroups = [self.safe getSubgroupsForGroup:group withFilter:nil deepSearch:NO];

        for (Group *subgroup in subGroups) {
            if ([self moveOrValidateItems:items destination:subgroup validate:YES]) {
                return YES;
            }
        }
    }

    return directMove;
}

- (void)moveItems:(NSArray *)items destination:(Group *)group {
    [self moveOrValidateItems:items destination:group validate:NO];
}

- (BOOL)moveOrValidateItems:(NSArray *)items destination:(Group *)destination validate:(BOOL)validate {
    for (SafeItemViewModel *item in items) {
        if (item.isGroup) {
            if (![self.safe moveGroup:item.group destination:destination validate:validate]) {
                return NO;
            }
        }
        else {
            if (![self.safe moveRecord:item.record destination:destination validate:validate]) {
                return NO;
            }
        }
    }

    return YES;
}

- (SafeItemViewModel *)renameItem:(SafeItemViewModel *)item title:(NSString *)title {
    if (item.isGroup) {
        Group *parentGroup = [item.group getParentGroup];
        Group *newGroup = [_safe addSubgroupWithUIString:parentGroup title:title];

        if (newGroup != nil) {
            NSArray *childItems = [self getItemsForGroup:item.group];

            if ([self moveOrValidateItems:childItems destination:newGroup validate:YES]) {
                if (![self moveOrValidateItems:childItems destination:newGroup validate:NO]) {
                    return nil;
                }

                // delete the old

                [self.safe deleteGroup:item.group];

                return [[SafeItemViewModel alloc] initWithGroup:newGroup];
            }
            else {
                return nil;
            }
        }
        else {
            return nil;
        }
    }
    else {
        item.title = title;
        return item;
    }
}

- (void)deleteItems:(NSArray<SafeItemViewModel *> *)items {
    for (SafeItemViewModel *item in items) {
        [self deleteItem:item];
    }
}

- (void)deleteItem:(SafeItemViewModel *)item {
    if (item.isGroup) {
        [self.safe deleteGroup:item.group];
    }
    else {
        [self.safe deleteRecord:item.record];
    }
}

////////////////////////////////////////////////////////////////////////////////////////////
// Auto complete helper

- (NSSet *)getAllExistingUserNames {
    NSMutableSet *bag = [[NSMutableSet alloc]init];

    for (Record *record in [self.safe getAllRecords]) {
        [bag addObject:record.username];
    }

    return bag;
}

- (NSSet *)getAllExistingPasswords {
    NSMutableSet *bag = [[NSMutableSet alloc]init];

    for (Record *record in [self.safe getAllRecords]) {
        [bag addObject:record.password];
    }

    return bag;
}

- (NSString *)getMostPopularUsername {
    NSCountedSet *bag = [[NSCountedSet alloc]init];

    for (Record *record in [self.safe getAllRecords]) {
        if(record.username.length) {
            [bag addObject:record.username];
        }
    }
    
    NSString *mostOccurring = @"";
    NSUInteger highest = 0;

    for (NSString *s in bag) {
        if ([bag countForObject:s] > highest) {
            highest = [bag countForObject:s];
            mostOccurring = s;
        }
    }

    return mostOccurring;
}

- (NSString *)getMostPopularPassword {
    NSCountedSet *bag = [[NSCountedSet alloc]init];

    for (Record *record in [self.safe getAllRecords]) {
        [bag addObject:record.password];
    }

    NSString *mostOccurring = @"";
    NSUInteger highest = 0;

    for (NSString *s in bag) {
        if ([bag countForObject:s] > highest) {
            highest = [bag countForObject:s];
            mostOccurring = s;
        }
    }

    return mostOccurring;
}

- (NSString *)generatePassword {
    NSString *letters = @"!@#$%*[];?()abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

    NSUInteger len = 16;
    NSMutableString *randomString = [NSMutableString stringWithCapacity:len];

    for (int i = 0; i < len; i++) {
        [randomString appendFormat:@"%C", [letters characterAtIndex:arc4random_uniform((u_int32_t)letters.length)]];
    }

    return randomString;
}

- (NSData *)getAsData {
    return [self.safe getAsData];
}

@end
