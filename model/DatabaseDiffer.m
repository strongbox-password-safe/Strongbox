//
//  DatabaseDiffer.m
//  Strongbox
//
//  Created by Strongbox on 02/01/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "DatabaseDiffer.h"
#import "NSArray+Extensions.h"

@implementation DatabaseDiffer

+ (DiffSummary *)diff:(DatabaseModel*)first second:(DatabaseModel*)second {
    BOOL canCompareGroupNodes = (first.originalFormat == kKeePass || first.originalFormat == kKeePass4) && (second.originalFormat == kKeePass || second.originalFormat == kKeePass4);
    BOOL canCompareNodeLocations = (first.originalFormat == kKeePass || first.originalFormat == kKeePass4) && (second.originalFormat == kKeePass || second.originalFormat == kKeePass4);

    NSSet<NSUUID*>* beforeIds = [first.rootNode.allChildren map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.uuid;
    }].set;
    
    NSSet<NSUUID*>* afterIds = [second.rootNode.allChildren map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.uuid;
    }].set;
    
    NSMutableSet<NSUUID*>* unionIds = beforeIds.mutableCopy;
    [unionIds unionSet:afterIds];
    
    NSMutableArray<NSUUID*> *onlyInSecond = @[].mutableCopy;
    NSMutableArray<NSUUID*> *edited = @[].mutableCopy;
    NSMutableArray<NSUUID*> *historicalChanges = @[].mutableCopy;
    NSMutableArray<NSUUID*> *moved = @[].mutableCopy;
    NSMutableArray<NSUUID*> *reordered = @[].mutableCopy;
    NSMutableArray<NSUUID*> *onlyInFirst = @[].mutableCopy;
    
    for (NSUUID* uuid in unionIds) {
        Node* a = [first getItemById:uuid];
        Node* b = [second getItemById:uuid];
        if ( !canCompareGroupNodes && (a.isGroup || b.isGroup)) {
            continue;
        }

        if (b && !a) {
            [onlyInSecond addObject:b.uuid];
        }
        else if (a && !b) {
            [onlyInFirst addObject:a.uuid];
        }
        else if (a && b) {
            BOOL editThis = NO;
            if (![a isSyncEqualTo:b isForUIDiffReport:YES]) {
                [edited addObject:a.uuid];
                editThis = YES;
            }

            if (!editThis) {
                if (![a isSyncEqualTo:b isForUIDiffReport:YES checkHistory:YES]) {
                    [historicalChanges addObject:a.uuid];
                }
            }

            
            
            if ( !canCompareNodeLocations ) {
                continue;
            }
            
            BOOL move = NO;
            if (b.parent != nil && a.parent != nil) {
                if ( b.parent == second.rootNode && a.parent == first.rootNode ) {
                    move = NO;
                }
                else if ([b.parent.uuid isEqual:a.parent.uuid]) {
                    NSUInteger beforeIndex = [a.parent.children indexOfObject:a];
                    NSUInteger afterIndex = [b.parent.children indexOfObject:b];

                    if (beforeIndex != afterIndex) {
                        move = NO;
                        [reordered addObject:a.uuid];
                    }
                }
                else {
                    move = YES;
                }
            }
            else if (b.parent == nil && a.parent == nil) {
                move = NO;
            }
            else {
                move = YES;
            }

            if (move) {
                [moved addObject:a.uuid];
            }
        }
        else {
            slog(@"WARNWARN: Diff could not find item! [%@]", uuid);
        }
    }
    
    

    UnifiedDatabaseMetadata* me = first.meta;
    UnifiedDatabaseMetadata* thee = second.meta;

    BOOL colorDifferent = !((me.color.length == 0 && thee.color.length == 0) || (me.color && [me.color compare:thee.color] == NSOrderedSame));
    BOOL nameDifferent = !((me.databaseName.length == 0 && thee.databaseName.length == 0) || (me.databaseName && [me.databaseName compare:thee.databaseName] == NSOrderedSame));
    BOOL descDifferent = !((me.databaseDescription.length == 0 && thee.databaseDescription.length == 0) || (me.databaseDescription && [me.databaseDescription compare:thee.databaseDescription] == NSOrderedSame));
    BOOL usernameDifferent = !((me.defaultUserName.length == 0 && thee.defaultUserName.length == 0) || (me.defaultUserName && [me.defaultUserName compare:thee.defaultUserName] == NSOrderedSame));
    BOOL recycleBinDifferent = !(me.recycleBinEnabled == thee.recycleBinEnabled);
    BOOL customDataDifferent = ![me.customData isEqualToDictionary:thee.customData];
        
    BOOL propertiesDifferent = colorDifferent | nameDifferent | descDifferent | usernameDifferent | recycleBinDifferent | customDataDifferent;
    
    DiffSummary* ret = [[DiffSummary alloc] init];

    ret.onlyInSecond = onlyInSecond;
    ret.edited = edited;
    ret.moved = moved;
    ret.reordered = reordered;
    ret.onlyInFirst = onlyInFirst;
    ret.historicalChanges = historicalChanges;
    ret.databasePropertiesDifferent = propertiesDifferent;
    
    ret.differenceMeasure = unionIds.count ? ((double)(ret.onlyInSecond.count + ret.edited.count + ret.historicalChanges.count + ret.moved.count + ret.onlyInFirst.count + (ret.databasePropertiesDifferent ? 1 : 0)) / (double)unionIds.count) : 0.0f;
    ret.differenceMeasure = MIN(1.0, ret.differenceMeasure);

    return ret;
}

@end
