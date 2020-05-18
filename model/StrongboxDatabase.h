//
//  StrongboxDatabase.h
//  
//
//  Created by Mark on 16/11/2018.
//

#import <Foundation/Foundation.h>
#import "Node.h"
#import "AbstractDatabaseMetadata.h"
#import "DatabaseAttachment.h"
#import "UiAttachment.h"
#import "CompositeKeyFactors.h"
#import "DeletedItem.h"

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface StrongboxDatabase : NSObject

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithMetadata:(id<AbstractDatabaseMetadata>)metadata
             compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors;

- (instancetype)initWithRootGroup:(Node*)rootGroup
                         metadata:(id<AbstractDatabaseMetadata>)metadata
              compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors;

- (instancetype)initWithRootGroup:(Node*)rootGroup
                         metadata:(id<AbstractDatabaseMetadata>)metadata
              compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors
                      attachments:(NSArray<DatabaseAttachment*>*)attachments;

- (instancetype)initWithRootGroup:(Node*)rootGroup
                         metadata:(id<AbstractDatabaseMetadata>)metadata
              compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors
                      attachments:(NSArray<DatabaseAttachment*>*)attachments
                      customIcons:(NSDictionary<NSUUID*, NSData*>*)customIcons;

- (instancetype)initWithRootGroup:(Node*)rootGroup
                         metadata:(id<AbstractDatabaseMetadata>)metadata
              compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors
                      attachments:(NSArray<DatabaseAttachment*>*)attachments
                      customIcons:(NSDictionary<NSUUID*, NSData*>*)customIcons
                   deletedObjects:(NSArray<DeletedItem*>*)deletedObjects NS_DESIGNATED_INITIALIZER;


@property (nullable) NSObject* adaptorTag; // Used by the adaptors to keep hold of unmodelled/unused data across loads/saves

@property (nonatomic, readonly) Node* rootGroup;
@property (nonatomic, readonly) id<AbstractDatabaseMetadata> metadata;
@property (nonatomic, readonly) NSArray<DatabaseAttachment*> *attachments;
@property (nonatomic, readonly) NSDictionary<NSUUID*, NSData*>* customIcons;
@property (nonatomic, readonly) NSArray<DeletedItem*> *deletedObjects;

@property (nonatomic, readonly, nonnull) CompositeKeyFactors *compositeKeyFactors;

@property BOOL recycleBinEnabled;
@property (nullable, readonly) NSUUID* recycleBinNodeUuid;   // NOT read-only because we made to set on demand
@property (nullable, readonly) NSDate* recycleBinChanged;
@property (nullable, readonly) Node* recycleBinNode;
@property (nullable, readonly) Node* keePass1BackupNode;
    
- (void)createNewRecycleBinNode;

- (void)removeNodeAttachment:(Node*)node atIndex:(NSUInteger)atIndex;
- (void)addNodeAttachment:(Node*)node attachment:(UiAttachment*)attachment;
- (void)addNodeAttachment:(Node*)node attachment:(UiAttachment*)attachment rationalize:(BOOL)rationalize;
- (void)setNodeAttachments:(Node*)node attachments:(NSArray<UiAttachment*>*)attachments;
- (void)setNodeCustomIcon:(Node*)node data:(NSData*)data rationalize:(BOOL)rationalize;

- (void)deleteItem:(Node *)item;
- (BOOL)recycleItem:(Node *)item;

- (BOOL)moveItems:(const NSArray<Node *> *)items destination:(Node*)destination keePassGroupTitleRules:(BOOL)keePassGroupTitleRules;

- (void)performPreSerializationTidy;

@end

NS_ASSUME_NONNULL_END
