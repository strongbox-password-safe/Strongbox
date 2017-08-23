//
//  PasswordDatabase.m
//
//
//  Created by Mark on 01/09/2015.
//
//

#import <Foundation/Foundation.h>
#import "PasswordDatabase.h"
#import "PasswordSafe3Database.h"

//////////////////////////////////////////////////////////////////////////////////////////////////////
// Search


@interface PasswordDatabase ()

@property (readonly) PasswordSafe3Database *safe;

@end

@implementation PasswordDatabase

- (instancetype)initNewWithoutPassword {
    PasswordSafe3Database* db = [[PasswordSafe3Database alloc] initNewWithoutPassword];
    
    return [self initWithSafeDatabase:db];
}

- (instancetype)initNewWithPassword:(NSString *)password {
    PasswordSafe3Database* db = [[PasswordSafe3Database alloc] initNewWithPassword:password];
    
    return [self initWithSafeDatabase:db];
}

- (instancetype)initExistingWithDataAndPassword:(NSData *)data password:(NSString *)password error:(NSError **)ppError {
    PasswordSafe3Database* db = [[PasswordSafe3Database alloc] initExistingWithData:password data:data error:ppError];
    
    if(db == nil) {
        return nil;
    }
    
    return [self initWithSafeDatabase:db];
}

- (instancetype)initWithSafeDatabase:(PasswordSafe3Database *)safe {
    if (self = [super init]) {
        _safe = safe;
        return self;
    }
    else {
        return nil;
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString*)masterPassword {
    return self.safe.masterPassword;
}

- (void)setMasterPassword:(NSString*)masterPassword {
    self.safe.masterPassword = masterPassword;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (SafeItemViewModel*)addRecord:(NSString*)title group:(Group*)group username:(NSString*)username url:(NSString*)url password:(NSString*)password notes:(NSString*)notes {
    Record* record = [[Record alloc] init];
    
    record.title = title;
    record.username = username;
    record.password = password;
    record.url = url;
    record.notes = notes;
    record.group = group;
    
    return [[SafeItemViewModel alloc] initWithRecord:[self.safe addRecord:record]];
}

- (SafeItemViewModel*)addRecord:(Record *)newRecord {
   return [[SafeItemViewModel alloc] initWithRecord:[self.safe addRecord:newRecord]];
}

- (SafeItemViewModel *)createGroupWithTitle:(Group *)parentGroup title:(NSString *)title validateOnly:(BOOL)validateOnly {
    Group *newGroup = [_safe createGroupWithTitle:parentGroup title:title validateOnly:validateOnly];

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
                                  NSString *s1 = ((SafeItemViewModel *)obj1).title;
                                  NSString *s2 = ((SafeItemViewModel *)obj2).title;
                                  return [s1 compare:s2];
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
                                  NSString *s1 = ((SafeItemViewModel *)obj1).title;
                                  NSString *s2 = ((SafeItemViewModel *)obj2).title;
                                  return [s1 compare:s2];
                              }];

    NSMutableArray *recordsForCurrentGroup = [[NSMutableArray alloc] initWithArray:[                                                                                    self.safe getRecordsForGroup:group withFilter:filter deepSearch:deepSearch]];

    [recordsForCurrentGroup sortUsingComparator:^(id obj1, id obj2) {
                                NSString *s1 = ((SafeItemViewModel *)obj1).title;
                                NSString *s2 = ((SafeItemViewModel *)obj2).title;
                                return [s1 compare:s2];
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

- (BOOL)validateMoveItems:(NSArray<SafeItemViewModel*> *)items destination:(Group *)group {
    return [self validateMoveItems:items destination:group checkIfMoveIntoSubgroupOfDestinationOk:NO];
}

- (BOOL)validateMoveItems:(NSArray<SafeItemViewModel*> *)items destination:(Group *)group checkIfMoveIntoSubgroupOfDestinationOk:(BOOL)checkIfMoveIntoSubgroupOfDestinationOk {
    BOOL directMove = [self moveOrValidateItems:items destination:group validateOnly:YES];

    if (!directMove && checkIfMoveIntoSubgroupOfDestinationOk) {
        NSArray *subGroups = [self.safe getSubgroupsForGroup:group withFilter:nil deepSearch:NO];

        for (Group *subgroup in subGroups) {
            if ([self moveOrValidateItems:items destination:subgroup validateOnly:YES]) {
                return YES;
            }
        }
    }

    return directMove;
}

- (void)moveItems:(NSArray<SafeItemViewModel*> *)items destination:(Group *)group {
    [self moveOrValidateItems:items destination:group validateOnly:NO];
}

- (BOOL)moveOrValidateItems:(NSArray<SafeItemViewModel*> *)items destination:(Group *)destination validateOnly:(BOOL)validateOnly {
    for (SafeItemViewModel *item in items) {
        if (item.isGroup) {
            if (![self.safe moveGroup:item.group destination:destination validateOnly:validateOnly]) {
                return NO;
            }
        }
        else {
            if (![self.safe moveRecord:item.record destination:destination validateOnly:validateOnly]) {
                return NO;
            }
        }
    }

    return YES;
}

- (SafeItemViewModel *)setItemTitle:(SafeItemViewModel *)item title:(NSString *)title {
    if(item == nil) {
        NSLog(@"WARN: nil sent to setItemTitle!"); // TODO: Raise?
        return nil;
    }
    
    if (item.isGroup) {
        Group *parentGroup = [item.group getParentGroup];
        Group *newGroup = [_safe createGroupWithTitle:parentGroup title:title validateOnly:YES];

        if (newGroup != nil) {
            NSArray *childItems = [self getItemsForGroup:item.group];

            if ([self moveOrValidateItems:childItems destination:newGroup validateOnly:YES]) {
                //We could be renaming an empty group so create the empty group now in case it's not created by the move operation.
                
                Group *newGroup = [_safe createGroupWithTitle:parentGroup title:title validateOnly:NO];

                if (![self moveOrValidateItems:childItems destination:newGroup validateOnly:NO]) {
                    NSLog(@"Could move child items into new destination group %@", newGroup.escapedPathString);

                    return nil;
                }

                // delete the old

                [self.safe deleteGroup:item.group];

                return [[SafeItemViewModel alloc] initWithGroup:newGroup];
            }
            else {
                NSLog(@"Could move child items into new destination group %@", newGroup.escapedPathString);
                return nil;
            }
        }
        else {
            NSLog(@"Could not create destination group %@", newGroup.escapedPathString);
            return nil;
        }
    }
    else {
        item.record.title = title;
        return item;
    }
}

- (void)setItemUsername:(SafeItemViewModel *)item username:(NSString*)username {
    if(item.isGroup) {
        [NSException raise:@"Attempt to alter group like an record invalidly." format:@"Attempt to alter group like an record invalidly"];
    }
    
    item.record.username = username;
}

- (void)setItemUrl:(SafeItemViewModel *)item url:(NSString*)url {
    if(item.isGroup) {
        [NSException raise:@"Attempt to alter group like an record invalidly." format:@"Attempt to alter group like an record invalidly"];
    }

    item.record.url = url;
}

- (void)setItemPassword:(SafeItemViewModel *)item password:(NSString*)password {
    if(item.isGroup) {
        [NSException raise:@"Attempt to alter group like an record invalidly." format:@"Attempt to alter group like an record invalidly"];
    }
    
    item.record.password = password;
}

- (void)setItemNotes:(SafeItemViewModel *)item notes:(NSString*)notes {
    if(item.isGroup) {
        [NSException raise:@"Attempt to alter group like an record invalidly." format:@"Attempt to alter group like an record invalidly"];
    }
  
    item.record.notes = notes;
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

- (NSData *)getAsData:(NSError**)error {
    return [self.safe getAsData:error];
}

- (NSDate *)lastUpdateTime {
    return self.safe.lastUpdateTime;
}

- (NSString *)lastUpdateUser {
    return self.safe.lastUpdateUser;
}

- (NSString *)lastUpdateHost {
    return self.safe.lastUpdateHost;
}

- (NSString *)lastUpdateApp {
    return self.safe.lastUpdateApp;
}

+ (BOOL)isAValidSafe:(NSData *)candidate {
    return [PasswordSafe3Database isAValidSafe:candidate];
}

- (NSString*)getSerializationIdForItem:(SafeItemViewModel*)item {
    if(item == nil) {
        return nil;
    }
    
    if(item.isGroup) {
        return [NSString stringWithFormat:@"G%@", item.group.escapedPathString];
    }
    else {
        return [NSString stringWithFormat:@"R%@", item.record.uuid];
    }
}

- (SafeItemViewModel*)getItemFromSerializationId:(NSString*)serializationId {
    if(serializationId == nil || serializationId.length < 1) {
        return nil;
    }
    
    NSString *groupOrRecord = [serializationId substringToIndex:1];
    NSString *identifier = [serializationId substringFromIndex:1];

    if([groupOrRecord isEqualToString:@"R"]) {
        Record* record = [self.safe getRecordByUuid:identifier];
        
        if(record) {
            return [[SafeItemViewModel alloc] initWithRecord:record];
        }
    }
    else if([groupOrRecord isEqualToString:@"G"]) {
        Group* group = [self.safe getGroupByEscapedPathString:identifier];
        
        if(group) {
            return [[SafeItemViewModel alloc] initWithGroup:group];
        }
    }
    
    return nil;
}

@end
