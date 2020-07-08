//
//  DeletesAndMovesTest.m
//  StrongboxTests
//
//  Created by Strongbox on 14/05/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "StrongboxDatabase.h"
#import "DatabaseModel.h"
#import "Kdbx4Database.h"

@interface DeletesAndMovesTest : XCTestCase

@end

@implementation DeletesAndMovesTest

- (void)testSimpleDeleteOrRecycleKp1DeletedByDefault {
    DatabaseModel* model = [[DatabaseModel alloc] initNew:[CompositeKeyFactors password:@"a"] format:kKeePass1];
    
    Node* node = model.allRecords.firstObject;
    NSUInteger prevCount = model.allRecords.count;
    
    NSLog(@"Going to delete [%@]", node);
    
    BOOL wasRecycled = [model canRecycle:node];
    [model deleteItems:@[node]];
    
    XCTAssertFalse(wasRecycled);
    XCTAssertFalse(model.recycleBinEnabled);
    XCTAssertEqual(prevCount - 1, model.allRecords.count);
}

- (void)testSimpleDeleteOrRecyclePsafeDeletedByDefault {
    DatabaseModel* model = [[DatabaseModel alloc] initNew:[CompositeKeyFactors password:@"a"] format:kPasswordSafe];
    
    Node* node = model.allRecords.firstObject;
    NSUInteger prevCount = model.allRecords.count;
    
    NSLog(@"Going to delete [%@]", node);

    BOOL wasRecycled = [model canRecycle:node];
    [model deleteItems:@[node]];

    XCTAssertFalse(wasRecycled);
    XCTAssertFalse(model.recycleBinEnabled);
    XCTAssertEqual(prevCount - 1, model.allRecords.count);
}

- (void)testDeleteOrRecycleAndRecycleBinCreatedByDefaultKp4 {
    DatabaseModel* model = [[DatabaseModel alloc] initNew:[CompositeKeyFactors password:@"a"] format:kKeePass4];
    
    Node* node = model.rootGroup.childRecords.firstObject;
    
    NSLog(@"Going to delete [%@]", node);
    
    BOOL wasRecycled = [model canRecycle:node];
    [model recycleItems:@[node]];

    XCTAssertTrue(wasRecycled);
    XCTAssertTrue(model.recycleBinEnabled);
    XCTAssertNotNil(model.recycleBinNode);
    
    XCTAssertTrue(model.deletedObjects.count == 0);
}

- (void)testDeleteOrRecycleWithRecycleBinOffDeletedObjectsAddedToKp4 {
    DatabaseModel* model = [[DatabaseModel alloc] initNew:[CompositeKeyFactors password:@"a"] format:kKeePass4];
    
    model.recycleBinEnabled = NO;
    
    Node* node = model.rootGroup.childRecords.firstObject;
    
    NSLog(@"Going to delete [%@]", node);
    
    BOOL wasRecycled = [model canRecycle:node];
    [model deleteItems:@[node]];

    XCTAssertFalse(wasRecycled);
    XCTAssertFalse(model.recycleBinEnabled);
    XCTAssertTrue(model.deletedObjects.count == 1);

    NSLog(@"[%@]", model.deletedObjects);
}

- (void)testDeleteOrRecycleAndRecycleBinCreatedByDefaultKp {
    DatabaseModel* model = [[DatabaseModel alloc] initNew:[CompositeKeyFactors password:@"a"] format:kKeePass];
    
    Node* node = model.rootGroup.childRecords.firstObject;
    
    NSLog(@"Going to delete [%@]", node);
    
    BOOL wasRecycled = [model canRecycle:node];
    [model recycleItems:@[node]];

    XCTAssertTrue(wasRecycled);
    XCTAssertTrue(model.recycleBinEnabled);
    XCTAssertNotNil(model.recycleBinNode);
    
    XCTAssertTrue(model.deletedObjects.count == 0);
}

- (void)testDeleteOrRecycleRecycleBinOffDeletedObjectsAddedToKp {
    DatabaseModel* model = [[DatabaseModel alloc] initNew:[CompositeKeyFactors password:@"a"] format:kKeePass];
    
    model.recycleBinEnabled = NO;
    
    Node* node = model.rootGroup.childRecords.firstObject;
    
    NSLog(@"Going to delete [%@]", node);
    
    BOOL wasRecycled = [model canRecycle:node];
    [model deleteItems:@[node]];

    XCTAssertFalse(wasRecycled);
    XCTAssertFalse(model.recycleBinEnabled);
    XCTAssertTrue(model.deletedObjects.count == 1);

    NSLog(@"[%@]", model.deletedObjects);
}

- (void)testLocationChangedSetOnCreationEntry {
    DatabaseModel* model = [[DatabaseModel alloc] initNew:[CompositeKeyFactors password:@"a"] format:kKeePass4];
    
    Node* node = model.allRecords.firstObject;

    XCTAssertNotNil(node.fields.locationChanged);
}

- (void)testLocationChangedSetOnCreationGroup {
    DatabaseModel* model = [[DatabaseModel alloc] initNew:[CompositeKeyFactors password:@"a"] format:kKeePass4];
    
    Node* node = model.allGroups.firstObject;

    XCTAssertNotNil(node.fields.locationChanged);
}

- (void)testTouchPropertiesSerializedInOutKp4 {
    [self helperTestTouchPropertiesSerializedInOutKp4:kKeePass4 extendedKeePass2Properties:YES group:NO];
}

- (void)testTouchPropertiesSerializedInOutKp {
    [self helperTestTouchPropertiesSerializedInOutKp4:kKeePass extendedKeePass2Properties:YES group:NO];
}

- (void)testTouchPropertiesSerializedInOutKp1 {
    [self helperTestTouchPropertiesSerializedInOutKp4:kKeePass1 extendedKeePass2Properties:NO group:NO];
}

- (void)testTouchPropertiesSerializedInOutPsafe {
    [self helperTestTouchPropertiesSerializedInOutKp4:kPasswordSafe extendedKeePass2Properties:NO group:NO];
}

- (void)testTouchPropertiesSerializedInOutKp4Group {
    [self helperTestTouchPropertiesSerializedInOutKp4:kKeePass4 extendedKeePass2Properties:YES group:YES];
}

- (void)testTouchPropertiesSerializedInOutKpGroup {
    [self helperTestTouchPropertiesSerializedInOutKp4:kKeePass extendedKeePass2Properties:YES group:YES];
}

- (void)testTouchPropertiesSerializedInOutKp1Group {
    [self helperTestTouchPropertiesSerializedInOutKp4:kKeePass1 extendedKeePass2Properties:NO group:YES];
}

//- (void)testTouchPropertiesSerializedInOutPsafeGroup { PSAFE doesn't support group touch props
//    [self helperTestTouchPropertiesSerializedInOutKp4:kPasswordSafe extendedKeePass2Properties:NO group:YES];
//}

- (void)helperTestTouchPropertiesSerializedInOutKp4:(DatabaseFormat)format extendedKeePass2Properties:(BOOL)extendedKeePass2Properties group:(BOOL)group {
    DatabaseModel* model = [[DatabaseModel alloc] initNew:CompositeKeyFactors.unitTestDefaults format:format];
    
    const NSDate *theDate = [self arbitraryDate];
    const NSNumber *theNumber = @(1729);
    
    Node* e1 = group ? model.allGroups.firstObject : model.allRecords.firstObject;

    [e1.fields setTouchPropertiesWithCreated:theDate accessed:theDate modified:theDate locationChanged:theDate usageCount:theNumber];
    
    [model getAsData:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
        if(error) {
            NSLog(@"%@", error);
        }
        
        XCTAssertNil(error);
        XCTAssertNotNil(data);
        
        [DatabaseModel fromLegacyData:data
                                  ckf:CompositeKeyFactors.unitTestDefaults
                               config:DatabaseModelConfig.defaults
                           completion:^(BOOL userCancelled, DatabaseModel * _Nonnull model2, NSError * _Nonnull error) {
            if(error) {
                NSLog(@"%@", error);
            }
            
            XCTAssertNotNil(model2);
            
            Node* e2 = group ? model2.allGroups.firstObject : model2.allRecords.firstObject;

            XCTAssertEqual(e2.fields.created, theDate);
            XCTAssertEqual(e2.fields.accessed, theDate);
            XCTAssertEqual(e2.fields.modified, theDate);
            
            if (extendedKeePass2Properties) {
                XCTAssertEqual(e2.fields.locationChanged, theDate);
                XCTAssertEqual(e2.fields.usageCount.unsignedIntValue, theNumber.unsignedIntValue);
            }
        }];
    }];
}

//

- (void)testDeleteOrRecycleGroupRecycledByDefault {
    DatabaseModel* model = [[DatabaseModel alloc] initNew:[CompositeKeyFactors password:@"a"] format:kKeePass4];
    
    Node* node = model.rootGroup.childRecords.firstObject;
    
    NSLog(@"Going to delete [%@]", node);
    
    BOOL wasRecycled = [model canRecycle:node];
    [model recycleItems:@[node]];

    XCTAssertTrue(wasRecycled);
    XCTAssertTrue(model.recycleBinEnabled);
    XCTAssertNotNil(model.recycleBinNode);
    XCTAssertTrue(model.deletedObjects.count == 0);
}

- (void)testDeleteEmptyGroup {
    DatabaseModel* model = [[DatabaseModel alloc] initNew:[CompositeKeyFactors password:@"a"] format:kKeePass4];
    model.recycleBinEnabled = NO;
    
    Node* node = model.allGroups.firstObject;
    
    NSLog(@"Going to delete [%@]", node);
    
    BOOL wasRecycled = [model canRecycle:node];
    [model deleteItems:@[node]];

    XCTAssertFalse(wasRecycled);
    XCTAssertTrue(model.deletedObjects.count == 1);
    
    XCTAssertNotNil(model.deletedObjects[node.uuid]);
}

- (void)testDeleteGroupRecursivelyDeletesAndAddsToDeletedObjects {
    DatabaseModel* model = [[DatabaseModel alloc] initNew:[CompositeKeyFactors password:@"a"] format:kKeePass4];
    model.recycleBinEnabled = NO;
    
    Node* node = model.allGroups.firstObject;
        
    Node* g1 = [[Node alloc] initAsGroup:@"" parent:node keePassGroupTitleRules:YES uuid:nil];
    [node addChild:g1 keePassGroupTitleRules:YES];
    
    Node* e1 = [[Node alloc] initAsRecord:@"Entry 1" parent:g1];
    [g1 addChild:e1 keePassGroupTitleRules:YES];

    Node* g2 = [[Node alloc] initAsGroup:@"" parent:g1 keePassGroupTitleRules:YES uuid:nil];
    [g1 addChild:g2 keePassGroupTitleRules:YES];
    
    Node* e2 = [[Node alloc] initAsRecord:@"Entry 2" parent:g2];
    [g2 addChild:e2 keePassGroupTitleRules:YES];

    Node* g3 = [[Node alloc] initAsGroup:@"" parent:g2 keePassGroupTitleRules:YES uuid:nil];
    [g2 addChild:g3 keePassGroupTitleRules:YES];
    
    Node* e3 = [[Node alloc] initAsRecord:@"Entry 3" parent:g3];
    [g3 addChild:e3 keePassGroupTitleRules:YES];

    NSLog(@"Going to delete [%@]", node);
    
    BOOL wasRecycled = [model canRecycle:node];
    [model deleteItems:@[node]];

    XCTAssertFalse(wasRecycled);
    XCTAssertEqual(model.deletedObjects.count, 7);
    XCTAssertNotNil(model.deletedObjects[node.uuid]);
        
    NSLog(@"Deleted: [%@]", model.deletedObjects);
}

- (void)testTimeSort {
    NSDictionary<NSUUID*, NSArray<NSDate*>*>* byUuid = @{
        NSUUID.UUID : @[NSDate.date, [NSDate.date dateByAddingTimeInterval:60*60*24*2]]
    };

    NSLog(@"UnSorted: %@", byUuid);

    NSMutableDictionary<NSUUID*, NSDate*> *ret = NSMutableDictionary.dictionary;
    for (NSUUID* uuid in byUuid.allKeys) {
        NSArray<NSDate*>* deletes = byUuid[uuid];
        NSArray<NSDate*>* sortedDeletes = [deletes sortedArrayUsingComparator:^NSComparisonResult(NSDate*  _Nonnull obj1, NSDate*  _Nonnull obj2) {
            return [obj2 compare:obj1];
        }];
        
        ret[uuid] = sortedDeletes.firstObject;
    }
    
    NSLog(@"Sorted: %@", ret);
}
    
- (void)testDeleteUndelete {
    DatabaseModel* model = [[DatabaseModel alloc] initNew:[CompositeKeyFactors password:@"a"] format:kKeePass4];
    model.recycleBinEnabled = NO;
    
    Node* node = model.allGroups.firstObject;
        
    Node* g1 = [[Node alloc] initAsGroup:@"Test" parent:node keePassGroupTitleRules:YES uuid:nil];
    [node addChild:g1 keePassGroupTitleRules:YES];

    // Do in this order so we can check it has been inserted back in the right location (index) after undo]
    
    Node* g2 = [[Node alloc] initAsGroup:@"X-Ray" parent:g1 keePassGroupTitleRules:YES uuid:nil];
    [g1 addChild:g2 keePassGroupTitleRules:YES];

    Node* e1 = [[Node alloc] initAsRecord:@"Foo" parent:g1];
    [g1 addChild:e1 keePassGroupTitleRules:YES];
    
    Node* e2 = [[Node alloc] initAsRecord:@"Bar" parent:g2];
    [g2 addChild:e2 keePassGroupTitleRules:YES];

    Node* g3 = [[Node alloc] initAsGroup:@"Zephyr" parent:g2 keePassGroupTitleRules:YES uuid:nil];
    [g2 addChild:g3 keePassGroupTitleRules:YES];
    
    Node* e3 = [[Node alloc] initAsRecord:@"Zebra" parent:g3];
    [g3 addChild:e3 keePassGroupTitleRules:YES];
    
    NSLog(@"BEFORE: [%@]", node.description);

    XCTAssertEqual(g1.children.count, 2);
    XCTAssertEqual(node.allChildren.count, 6);
    XCTAssertEqual(model.deletedObjects.count, 0);

    ////////////////////////
    
    NSArray<NodeHierarchyReconstructionData*>* undoData = nil;
    [model deleteItems:@[g2] undoData:&undoData];

    XCTAssertEqual(model.deletedObjects.count, 4);
    XCTAssertNotNil(model.deletedObjects[g2.uuid]);
 
    // Now can we reconstruct and undo the delete:

    NSLog(@"Undo Data: [%@]", undoData);

    [model unDelete:undoData];

    XCTAssertEqual(g1.children.count, 2);
    
    Node* reconstructedG2 = [g1 findFirstChild:NO predicate:^BOOL(Node * _Nonnull node) {
        return [node.uuid isEqual:g2.uuid];
    }];
    
    XCTAssertEqual([g1.children indexOfObject:reconstructedG2], 0);

    XCTAssertEqual(node.allChildren.count, 6);
    XCTAssertEqual(model.deletedObjects.count, 0);

    NSLog(@"AFTER: [%@]", node.description);
}

//

- (void)testRecycleRecursive {
    DatabaseModel* model = [[DatabaseModel alloc] initNew:[CompositeKeyFactors password:@"a"] format:kKeePass4];
    model.recycleBinEnabled = YES;
    
    Node* node = model.rootGroup.childGroups.firstObject;
        
    Node* g1 = [[Node alloc] initAsGroup:@"subgroup" parent:node keePassGroupTitleRules:YES uuid:nil];
    [node addChild:g1 keePassGroupTitleRules:YES];
    
    Node* e1 = [[Node alloc] initAsRecord:@"Entry 1" parent:g1];
    [g1 addChild:e1 keePassGroupTitleRules:YES];

    Node* g2 = [[Node alloc] initAsGroup:@"sb2" parent:g1 keePassGroupTitleRules:YES uuid:nil];
    [g1 addChild:g2 keePassGroupTitleRules:YES];
    
    Node* e2 = [[Node alloc] initAsRecord:@"Entry 2" parent:g2];
    [g2 addChild:e2 keePassGroupTitleRules:YES];

    Node* g3 = [[Node alloc] initAsGroup:@"sb3" parent:g2 keePassGroupTitleRules:YES uuid:nil];
    [g2 addChild:g3 keePassGroupTitleRules:YES];
    
    Node* e3 = [[Node alloc] initAsRecord:@"Entry 3" parent:g3];
    [g3 addChild:e3 keePassGroupTitleRules:YES];

    NSLog(@"Going to recycle [%@]", node);
    
    NSDate* oldAccessed = node.fields.accessed;
    NSDate* oldLocationChanged = node.fields.locationChanged;
    
    BOOL wasRecycled = [model canRecycle:node];
    [model recycleItems:@[node]];

    XCTAssertTrue(wasRecycled);
    XCTAssertEqual(model.deletedObjects.count, 0);
    XCTAssertEqual(model.recycleBinNode.childGroups.count, 1);
    XCTAssertEqual(model.recycleBinNode.allChildren.count, 7);
    XCTAssertEqual(model.recycleBinNode.childGroups.firstObject.uuid, node.uuid);

    XCTAssertNotEqual(node.fields.accessed, oldAccessed);
    XCTAssertEqual(node.fields.accessed, model.rootGroup.fields.accessed);
    XCTAssertNotEqual(node.fields.locationChanged, oldLocationChanged);
    
}

- (void)testMove {
    DatabaseModel* model = [[DatabaseModel alloc] initNew:[CompositeKeyFactors password:@"a"] format:kKeePass4];
    model.recycleBinEnabled = YES;
    
    Node* node = model.rootGroup.childGroups.firstObject;
        
    Node* g1 = [[Node alloc] initAsGroup:@"subgroup" parent:node keePassGroupTitleRules:YES uuid:nil];
    [node addChild:g1 keePassGroupTitleRules:YES];
    
    Node* e1 = [[Node alloc] initAsRecord:@"Entry 1" parent:g1];
    [g1 addChild:e1 keePassGroupTitleRules:YES];

    Node* g2 = [[Node alloc] initAsGroup:@"sb2" parent:g1 keePassGroupTitleRules:YES uuid:nil];
    [g1 addChild:g2 keePassGroupTitleRules:YES];
    
    Node* e2 = [[Node alloc] initAsRecord:@"Entry 2" parent:g2];
    [g2 addChild:e2 keePassGroupTitleRules:YES];

    Node* g3 = [[Node alloc] initAsGroup:@"sb3" parent:g2 keePassGroupTitleRules:YES uuid:nil];
    [g2 addChild:g3 keePassGroupTitleRules:YES];
    
    Node* e3 = [[Node alloc] initAsRecord:@"Entry 3" parent:g3];
    [g3 addChild:e3 keePassGroupTitleRules:YES];

    NSLog(@"Going to recycle [%@]", node);
    
    NSDate* oldAccessed = g1.fields.accessed;
    NSDate* oldModified = g1.fields.modified;
    NSDate* oldLocationChanged = g1.fields.locationChanged;
    
    [model moveItems:@[g1] destination:model.rootGroup];

    XCTAssertEqual(g1.childGroups.count, 1);
    XCTAssertEqual(g1.allChildren.count, 5);
    XCTAssertEqual(g1.childGroups.firstObject.uuid, g2.uuid);

    XCTAssertEqual(g1.fields.accessed, oldAccessed);
    XCTAssertEqual(g1.fields.modified, oldModified);
    XCTAssertNotEqual(g1.fields.locationChanged, oldLocationChanged);
}

- (void)testDeletedObjectsSerializationKp {
    [self helperTestDeletedObjectsSerialization:kKeePass];
}

- (void)testDeletedObjectsSerializationKp4 {
    [self helperTestDeletedObjectsSerialization:kKeePass4];
}

- (void)helperTestDeletedObjectsSerialization:(DatabaseFormat)format {
    DatabaseModel* model = [[DatabaseModel alloc] initNew:CompositeKeyFactors.unitTestDefaults format:format];
    model.recycleBinEnabled = NO;
    Node* node = model.rootGroup.childRecords.firstObject;
    
    [model deleteItems:@[node]];

    XCTAssertEqual(model.deletedObjects.count, 1);
    
    [model deleteItems:@[model.rootGroup.allChildGroups.firstObject]];
    
    XCTAssertEqual(model.deletedObjects.count, 2);
    
    [model getAsData:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
        if(error) {
            NSLog(@"%@", error);
        }
        
        XCTAssertNil(error);
        XCTAssertNotNil(data);
        
        [DatabaseModel fromLegacyData:data
                                  ckf:CompositeKeyFactors.unitTestDefaults
                               config:DatabaseModelConfig.defaults
                           completion:^(BOOL userCancelled, DatabaseModel * _Nonnull model2, NSError * _Nonnull error) {
            if(error) {
                NSLog(@"%@", error);
            }
            
            XCTAssertNotNil(model2);
            XCTAssertEqual(model2.deletedObjects.count, 2);
            XCTAssertNotNil(model2.deletedObjects[node.uuid]);
        }];
    }];
}

//

- (NSDate*)arbitraryDate {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss zzz"];
    [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"ja_JP"]];

    return [dateFormatter dateFromString: @"1981-12-24 21:55:55 JST"];
}

@end
