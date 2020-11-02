#import <Foundation/Foundation.h>
#import "DatabaseModel.h"
#import "PwSafeDatabase.h"
#import "KeePassDatabase.h"
#import "AbstractDatabaseFormatAdaptor.h"
#import "Utils.h"
#import "Kdbx4Database.h"
#import "Kdb1Database.h"
#import "PasswordMaker.h"
#import "SprCompilation.h"
#import "NSArray+Extensions.h"
#import "NSMutableArray+Extensions.h"
#import "Kdbx4Serialization.h"
#import "KeePassCiphers.h"
#import "KissXML.h"
#import "NSArray+Extensions.h"
#import "DatabaseAuditor.h"
#import "NSData+Extensions.h"
#import "Constants.h"
#import "NSDate+Extensions.h"
#import "StreamUtils.h"
#import "LoggingInputStream.h"

@interface DatabaseModel ()

@property (nonatomic, strong) StrongboxDatabase* theSafe;
@property (nonatomic, strong) id<AbstractDatabaseFormatAdaptor> adaptor;
@property DatabaseModelConfig* config;

@end

@implementation DatabaseModel

+ (NSData*_Nullable)getValidationPrefixFromUrl:(NSURL*)url {
    NSInputStream* inputStream = [NSInputStream inputStreamWithURL:url];
    
    [inputStream open];
    
    uint8_t buf[kMinimumDatabasePrefixLengthForValidation];
    NSInteger bytesRead = [inputStream read:buf maxLength:kMinimumDatabasePrefixLengthForValidation];
    
    [inputStream close];
    
    if (bytesRead > 0) {
        return [NSData dataWithBytes:buf length:bytesRead];
    }
    
    return nil;
}

+ (BOOL)isValidDatabase:(NSURL *)url error:(NSError *__autoreleasing  _Nullable *)error {
    NSData* prefix = [DatabaseModel getValidationPrefixFromUrl:url];
    
    return [DatabaseModel isValidDatabaseWithPrefix:prefix error:error];
}
 
+ (BOOL)isValidDatabaseWithPrefix:(NSData *)prefix error:(NSError *__autoreleasing  _Nullable *)error {
    if(prefix == nil) {
        if(error) {
            *error = [Utils createNSError:@"Database Data is Nil" errorCode:-1];
        }
        return NO;
    }
    if(prefix.length == 0) {
        if(error) {
            *error = [Utils createNSError:@"Database Data is zero length" errorCode:-1];
        }
        return NO;
    }

    NSError *pw, *k1, *k2, *k3;
        
    BOOL ret = [PwSafeDatabase isValidDatabase:prefix error:&pw] ||
        [KeePassDatabase isValidDatabase:prefix error:&k1] ||
        [Kdbx4Database isValidDatabase:prefix error:&k2] ||
        [Kdb1Database isValidDatabase:prefix error:&k3];

    if(!ret && error) {
        NSData* prefixBytes = [prefix subdataWithRange:NSMakeRange(0, MIN(12, prefix.length))];
        
        NSString* errorSummary = @"Invalid Database. Debug Info:\n";
        
        NSString* prefix = prefixBytes.hex;
        
        if([prefix hasPrefix:@"004D534D414D415250435259"]) { // MSMAMARPCRY - https://github.com/strongbox-password-safe/Strongbox/issues/303
            NSString* loc = NSLocalizedString(@"error_database_is_encrypted_ms_intune", @"It looks like your database is encrypted by Microsoft InTune probably due to corporate policy.");
            
            errorSummary = loc;
        }
        else {
            errorSummary = [errorSummary stringByAppendingFormat:@"PFX: [%@]\n", prefix];
            errorSummary = [errorSummary stringByAppendingFormat:@"PWS: [%@]\n", pw.localizedDescription];
            errorSummary = [errorSummary stringByAppendingFormat:@"KP:[%@]-[%@]\n", k1.localizedDescription, k2.localizedDescription];
            errorSummary = [errorSummary stringByAppendingFormat:@"KP1: [%@]\n", k3.localizedDescription];
        }
        
        *error = [Utils createNSError:errorSummary errorCode:-1];
    }
    
    return ret;
}

+ (DatabaseFormat)getDatabaseFormat:(NSURL *)url {
    NSData* prefix = [DatabaseModel getValidationPrefixFromUrl:url];
    return [DatabaseModel getDatabaseFormatWithPrefix:prefix];
}

+ (DatabaseFormat)getDatabaseFormatWithPrefix:(NSData *)prefix {
    if(prefix == nil || prefix.length == 0) {
        return kFormatUnknown;
    }
    
    NSError* error;
    if([PwSafeDatabase isValidDatabase:prefix error:&error]) {
        return kPasswordSafe;
    }
    else if ([KeePassDatabase isValidDatabase:prefix error:&error]) {
        return kKeePass;
    }
    else if([Kdbx4Database isValidDatabase:prefix error:&error]) {
        return kKeePass4;
    }
    else if([Kdb1Database isValidDatabase:prefix error:&error]) {
        return kKeePass1;
    }
    
    return kFormatUnknown;
}

+ (NSString*)getLikelyFileExtension:(NSData *)prefix {
    DatabaseFormat format = [DatabaseModel getDatabaseFormatWithPrefix:prefix];
    
    if (format == kPasswordSafe) {
        return [PwSafeDatabase fileExtension];
    }
    else if (format == kKeePass4) {
        return [Kdbx4Database fileExtension];
    }
    else if (format == kKeePass) {
        return [KeePassDatabase fileExtension];
    }
    else if (format == kKeePass1) {
        return [Kdb1Database fileExtension];
    }
    else {
        return @"dat";
    }
}

+ (NSString*)getDefaultFileExtensionForFormat:(DatabaseFormat)format {
    if(format == kPasswordSafe) {
        return [PwSafeDatabase fileExtension];
    }
    else if (format == kKeePass) {
        return [KeePassDatabase fileExtension];
    }
    else if(format == kKeePass4) {
        return [Kdbx4Database fileExtension];
    }
    else if(format == kKeePass1) {
        return [Kdb1Database fileExtension];
    }
    
    return @"dat";
}

+ (id<AbstractDatabaseFormatAdaptor>)getAdaptor:(DatabaseFormat)format {
    if(format == kPasswordSafe) {
        return [[PwSafeDatabase alloc] init];
    }
    else if(format == kKeePass) {
        return [[KeePassDatabase alloc] init];
    }
    else if(format == kKeePass4) {
        return [[Kdbx4Database alloc] init];
    }
    else if(format == kKeePass1) {
        return [[Kdb1Database alloc] init];
    }
    
    NSLog(@"WARN: No such adaptor for format!");
    return nil;
}

//////
// Mostly shouldn't be used in normal course of events - used by Duress Dummy to simplify coding...

- (NSData*)expressToData {
    __block NSData* ret;

    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);

    [self getAsData:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
        if (userCancelled || error) {
            NSLog(@"Error: expressToData [%@]", error);
        }
        else {
            ret = data;
        }
        dispatch_group_leave(group);
    }];

    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

    return ret;
}

+ (instancetype)expressFromData:(NSData*)data password:(NSString*)password config:(DatabaseModelConfig*)config {
    DatabaseFormat format = [DatabaseModel getDatabaseFormatWithPrefix:data];
    id<AbstractDatabaseFormatAdaptor> adaptor = [DatabaseModel getAdaptor:format];
    if (adaptor == nil) {
       return nil;
    }

    __block DatabaseModel* model = nil;
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);

    NSInputStream* stream = [NSInputStream inputStreamWithData:data];
    [stream open];
    [adaptor read:stream
              ckf:[CompositeKeyFactors password:password]
    xmlDumpStream:nil
sanityCheckInnerStream:config.sanityCheckInnerStream
     completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable database, NSError * _Nullable error) {
        [stream close];
      
        if(userCancelled || database == nil || error) {
            NSLog(@"Error: expressFromData = [%@]", error);
            model = nil;
        }
        else {
            model = [[DatabaseModel alloc] initWithDatabase:database adaptor:adaptor config:config];
        }
        
        dispatch_group_leave(group);
    }];

    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

    return model;
}


//////
+ (void)fromUrlOrLegacyData:(NSURL *)url
                 legacyData:(NSData *)legacyData
                        ckf:(CompositeKeyFactors *)ckf
                     config:(DatabaseModelConfig *)config
                 completion:(void (^)(BOOL, DatabaseModel * _Nullable, const NSError * _Nullable))completion {
    if (url) {
        [DatabaseModel fromUrl:url ckf:ckf config:config completion:completion];
    }
    else {
        [DatabaseModel fromLegacyData:legacyData ckf:ckf config:config completion:completion];
    }
}

+ (void)fromLegacyData:legacyData
                   ckf:(CompositeKeyFactors *)ckf
                config:(DatabaseModelConfig*)config
            completion:(void (^)(BOOL, DatabaseModel * _Nullable, NSError * _Nullable))completion {
    NSInputStream* stream = [NSInputStream inputStreamWithData:legacyData];
    
    DatabaseFormat format = [DatabaseModel getDatabaseFormatWithPrefix:legacyData];

    [DatabaseModel fromStreamWithFormat:stream
                                    ckf:ckf
                                 config:config
                                 format:format
                          xmlDumpStream:nil
                             completion:completion];
}

+ (void)fromUrl:(NSURL *)url
            ckf:(CompositeKeyFactors *)ckf
         config:(DatabaseModelConfig *)config
     completion:(void (^)(BOOL, DatabaseModel * _Nullable, const NSError * _Nullable))completion {
    [DatabaseModel fromUrl:url ckf:ckf config:config xmlDumpStream:nil  completion:completion];
}

+ (void)fromUrl:(NSURL *)url
            ckf:(CompositeKeyFactors *)ckf
         config:(DatabaseModelConfig *)config
  xmlDumpStream:(NSOutputStream *)xmlDumpStream
     completion:(void (^)(BOOL, DatabaseModel * _Nullable, const NSError * _Nullable))completion {
    DatabaseFormat format = [DatabaseModel getDatabaseFormat:url];
     
    NSInputStream* stream = [NSInputStream inputStreamWithURL:url];
    
    // NSData* foo = [StreamUtils readAll:stream];
    //    LoggingInputStream* lis = [[LoggingInputStream alloc] initWithStream:stream];
    
    [DatabaseModel fromStreamWithFormat:stream
                                    ckf:ckf
                                 config:config
                                 format:format
                          xmlDumpStream:xmlDumpStream
                             completion:completion];
}

+ (void)fromStreamWithFormat:(NSInputStream *)stream
                         ckf:(CompositeKeyFactors *)ckf
                      config:(DatabaseModelConfig*)config
                      format:(DatabaseFormat)format
               xmlDumpStream:(NSOutputStream*_Nullable)xmlDumpStream
                  completion:(void(^)(BOOL userCancelled, DatabaseModel*_Nullable model, NSError*_Nullable error))completion {
    id<AbstractDatabaseFormatAdaptor> adaptor = [DatabaseModel getAdaptor:format];

    if (adaptor == nil) {
        completion(NO, nil, nil);
        return;
    }
    
    NSTimeInterval startDecryptTime = NSDate.timeIntervalSinceReferenceDate;
    
    [stream open];
    
    [adaptor read:stream
              ckf:ckf
    xmlDumpStream:xmlDumpStream
     sanityCheckInnerStream:config.sanityCheckInnerStream
       completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable database, NSError * _Nullable error) {
        
        [stream close];
        
        NSLog(@"====================================== PERF ======================================");
        NSLog(@"DESERIALIZE [%f] seconds", NSDate.timeIntervalSinceReferenceDate - startDecryptTime);
        NSLog(@"====================================== PERF ======================================");

        if(userCancelled || database == nil || error) {
            completion(userCancelled, nil ,error);
        }
        else {
            DatabaseModel* model = [[DatabaseModel alloc] initWithDatabase:database adaptor:adaptor config:config];
            completion(NO, model, nil);
        }
    }];
}

//

- (instancetype)initWithDatabase:(StrongboxDatabase*)database
                         adaptor:(id<AbstractDatabaseFormatAdaptor>)adaptor
                          config:(DatabaseModelConfig*)config {
    if (self = [super init]) {
        if (adaptor == nil) {
            return nil;
        }
        if (database == nil) {
            return nil;
        }
        
        self.adaptor = adaptor;
        self.theSafe = database;
    }
    return self;
}

- (instancetype)initWithFormat:(DatabaseFormat)format compositeKeyFactors:(CompositeKeyFactors *)compositeKeyFactors {
    return [self initWithFormat:format compositeKeyFactors:compositeKeyFactors config:DatabaseModelConfig.defaults];
}

- (instancetype)initWithFormat:(DatabaseFormat)format
           compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors
                        config:(DatabaseModelConfig*)config {
    id<AbstractDatabaseFormatAdaptor> adaptor = [DatabaseModel getAdaptor:format];
    if (adaptor == nil) {
        return nil;
    }
    
    StrongboxDatabase* database = [adaptor create:compositeKeyFactors];
    
    return [self initWithDatabase:database adaptor:adaptor config:config];
}

- (instancetype)initEmptyForTesting:(CompositeKeyFactors *)compositeKeyFactors {
    DatabaseModelConfig* config = [DatabaseModelConfig withPasswordConfig:PasswordGenerationConfig.defaults];
    
    return [self initWithFormat:kKeePass compositeKeyFactors:compositeKeyFactors config:config];
}

- (instancetype)initNew:(CompositeKeyFactors *)compositeKeyFactors
                 format:(DatabaseFormat)format {
    return [self initNew:compositeKeyFactors format:format config:DatabaseModelConfig.defaults];
}

- (instancetype)initNew:(CompositeKeyFactors *)compositeKeyFactors
                 format:(DatabaseFormat)format
                 config:(DatabaseModelConfig*)config {
    if (self = [self initWithFormat:format compositeKeyFactors:compositeKeyFactors config:config]) {
        if(format != kKeePass1) {
            [self addSampleGroupAndRecordToRoot];
        }
        else {
            Node *parent = self.theSafe.rootGroup.childGroups[0];
            [self addSampleGroupAndRecordToGroup:parent];
        }
    }
    
    return self;
}

- (void)getAsData:(SaveCompletionBlock)completion {
    [self.theSafe performPreSerializationTidy]; // Tidy up attachments, custom icons, trim history
    
    [self.adaptor save:self.theSafe completion:completion];
}

- (void)addSampleGroupAndRecordToRoot {
    [self addSampleGroupAndRecordToGroup:self.rootGroup];
}

- (void)addSampleGroupAndRecordToGroup:(Node*)parent {
    NSString* password = [PasswordMaker.sharedInstance generateForConfigOrDefault:self.config.passwordGeneration];

    Node* sampleFolder = [[Node alloc] initAsGroup:NSLocalizedString(@"model_sample_group_title", @"Sample Group")
                                            parent:parent
                            keePassGroupTitleRules:YES
                                              uuid:nil];
    
    [parent addChild:sampleFolder keePassGroupTitleRules:NO];
    
    NodeFields *fields = [[NodeFields alloc] initWithUsername:NSLocalizedString(@"model_sample_entry_username", @"username")
                                                          url:@"https://strongboxsafe.com"
                                                     password:password
                                                        notes:@""
                                                        email:@"user@gmail.com"];

    [parent addChild:[[Node alloc] initAsRecord:NSLocalizedString(@"model_sample_entry_title", @"Sample")
                                         parent:parent
                                         fields:fields
                                           uuid:nil]
                         keePassGroupTitleRules:NO];
}

//

- (void)addHistoricalNode:(Node*)item originalNodeForHistory:(Node*)originalNodeForHistory {
    BOOL shouldAddHistory = YES; // FUTURE: Config on/off? only valid for KeePass 2+ also...
    
    if(shouldAddHistory && !item.isGroup && originalNodeForHistory != nil) {
        [item.fields.keePassHistory addObject:originalNodeForHistory];
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Simple Field Edits

- (BOOL)setItemTitle:(Node *)item title:(NSString *)title {
    Node* originalNodeForHistory = [item cloneForHistory];

    BOOL ret = [item setTitle:title keePassGroupTitleRules:self.format != kPasswordSafe];

    if (ret) {
        [self addHistoricalNode:item originalNodeForHistory:originalNodeForHistory];
        [item touch:YES touchParents:NO];
    }
    
    return ret;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)isDereferenceableText:(NSString*)text {
    return self.format != kPasswordSafe && [SprCompilation.sharedInstance isSprCompilable:text];
}

- (NSString*)maybeDeref:(NSString*)text node:(Node*)node maybe:(BOOL)maybe {
    return maybe ? [self dereference:text node:node] : text;
}

- (NSString*)dereference:(NSString*)text node:(Node*)node {
    if(self.format == kPasswordSafe || !text.length) {
        return text;
    }
    
    NSError* error;
    
    BOOL isCompilable = [SprCompilation.sharedInstance isSprCompilable:text];
    
    NSString* compiled = isCompilable ? [SprCompilation.sharedInstance sprCompile:text node:node rootNode:self.rootGroup error:&error] : text;
    
    if(error) {
        NSLog(@"WARN: SPR Compilation ERROR: [%@]", error);
    }
    
    return compiled ? compiled : @""; // Never return nil... just not expected at UI layer
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)getGroupPathDisplayString:(Node *)vm {
    NSMutableArray<NSString*> *hierarchy = [NSMutableArray array];
    
    Node* current = vm;
    while (current != nil && current != self.rootGroup) {
        [hierarchy insertObject:current.title atIndex:0];
        current = current.parent;
    }
    
    return hierarchy.count ? [hierarchy componentsJoinedByString:@"/"] : @"/";
}

- (NSString *)getSearchParentGroupPathDisplayString:(Node *)vm {
    if(!vm || vm.parent == nil || vm.parent == self.rootGroup) {
        return @"/";
    }
    
    NSMutableArray<NSString*> *hierarchy = [NSMutableArray array];
    
    Node* current = vm;
    while (current.parent != nil && current.parent != self.rootGroup) {
        [hierarchy insertObject:current.parent.title atIndex:0]; 
        current = current.parent;
    }
    
    NSString *path = [hierarchy componentsJoinedByString:@"/"];
    
    return path;
}

- (Node*)rootGroup {
    if(self.format == kKeePass || self.format == kKeePass4) {
        // Hide the root group - Can not add entries and not really useful - Perhaps make this optional?
        // Later discovery: KeePass 1 allows multiple root groups but no entries to root, Had to put in
        // Code to block root entry additions, meaning that we could display the root group here if we
        // wanted to, and block entries. For the moment, happy to hide the root group for KeePass 3 and 4
        // we'll see if there is some feedback on this. Root Group seems to be pretty useless
        
        if(self.theSafe.rootGroup.children.count > 0) {
            return [self.theSafe.rootGroup.children objectAtIndex:0];
        }
        else {
            return self.theSafe.rootGroup; // This should never be able to happen but for safety
        }
    }
    else {
        return self.theSafe.rootGroup;
    }
}

- (DatabaseFormat)format {
    return self.adaptor.format;
}

- (NSString *)fileExtension {
    return self.adaptor.fileExtension;
}

-(id<AbstractDatabaseMetadata>)metadata {
    return self.theSafe.metadata;
}

-(NSArray<DatabaseAttachment *> *)attachments {
    return self.theSafe.attachments;
}

- (NSDictionary<NSUUID *,NSData *> *)customIcons {
    return self.theSafe.customIcons;
}

- (void)addNodeAttachment:(Node *)node attachment:(UiAttachment*)attachment {
    [self addNodeAttachment:node attachment:attachment rationalize:YES];
}

- (void)addNodeAttachment:(Node *)node attachment:(UiAttachment*)attachment rationalize:(BOOL)rationalize {
    [self.theSafe addNodeAttachment:node attachment:attachment rationalize:rationalize];
}

- (void)removeNodeAttachment:(Node *)node atIndex:(NSUInteger)atIndex {
    [self.theSafe removeNodeAttachment:node atIndex:atIndex];
}

- (void)setNodeAttachments:(Node *)node attachments:(NSArray<UiAttachment *> *)attachments {
    [self.theSafe setNodeAttachments:node attachments:attachments];
}

- (void)setNodeCustomIcon:(Node *)node data:(NSData *)data rationalize:(BOOL)rationalize {
    [self setNodeCustomIcon:node data:data rationalize:rationalize addHistory:YES];
}

- (void)setNodeCustomIcon:(Node *)node data:(NSData *)data rationalize:(BOOL)rationalize addHistory:(BOOL)addHistory {
    if (addHistory) {
        Node* originalNodeForHistory = [node cloneForHistory];
        [self addHistoricalNode:node originalNodeForHistory:originalNodeForHistory];
    }
    
    [node touch:YES touchParents:NO];
    [self.theSafe setNodeCustomIcon:node data:data rationalize:rationalize];
}

- (void)setNodeCustomIconUuid:(Node *)node uuid:(NSUUID *)uuid rationalize:(BOOL)rationalize {
    [self setNodeCustomIconUuid:node uuid:uuid rationalize:rationalize addHistory:YES];
}

- (void)setNodeCustomIconUuid:(Node *)node uuid:(NSUUID *)uuid rationalize:(BOOL)rationalize addHistory:(BOOL)addHistory {
    if (addHistory) {
        Node* originalNodeForHistory = [node cloneForHistory];
        [self addHistoricalNode:node originalNodeForHistory:originalNodeForHistory];
    }
    
    [node touch:YES touchParents:NO];

    [self.theSafe setNodeCustomIconUuid:node uuid:uuid rationalize:rationalize];
}


- (void)setNodeIconId:(Node *)node iconId:(NSNumber *)iconId rationalize:(BOOL)rationalize {
    [self setNodeIconId:node iconId:iconId rationalize:rationalize addHistory:YES];
}

- (void)setNodeIconId:(Node *)node iconId:(NSNumber *)iconId rationalize:(BOOL)rationalize addHistory:(BOOL)addHistory {
    if (addHistory) {
        Node* originalNodeForHistory = [node cloneForHistory];
        [self addHistoricalNode:node originalNodeForHistory:originalNodeForHistory];
    }
    
    [node touch:YES touchParents:NO];

    if(iconId.intValue == -1) {
        node.iconId = !node.isGroup ? @(0) : @(48); // Default
    }
    else {
        node.iconId = iconId;
    }
    node.customIconUuid = nil;
}

////////////////////////////////

- (void)setRecycleBinEnabled:(BOOL)recycleBinEnabled {
    self.theSafe.recycleBinEnabled = recycleBinEnabled;
}

- (BOOL)recycleBinEnabled {
    return self.theSafe.recycleBinEnabled;
}

- (Node*)recycleBinNode {
    return self.theSafe.recycleBinNode;
}

- (Node *)keePass1BackupNode {
    return self.theSafe.keePass1BackupNode;
}

- (NSSet<Node *> *)getMinimalNodeSet:(const NSArray<Node *> *)nodes {
    return [self.theSafe getMinimalNodeSet:nodes];
}

/////////////////////////////////////////////////////////////////////////////////////////////
// Delete

- (NSDictionary<NSUUID *,NSDate *> *)deletedObjects {
    return self.theSafe.deletedObjects;
}

- (void)deleteItems:(const NSArray<Node *> *)items {
    [self deleteItems:items undoData:nil];
}

- (void)deleteItems:(const NSArray<Node *> *)items undoData:(NSArray<NodeHierarchyReconstructionData *>**)undoData {
    [self.theSafe deleteItems:items undoData:undoData];
}

- (void)unDelete:(NSArray<NodeHierarchyReconstructionData *> *)undoData {
    [self.theSafe unDelete:undoData];
}

/////////////////////////////////////////////////////////////////////////////////////////////
// Recycle

- (BOOL)canRecycle:(Node *)item {
    return [self.theSafe canRecycle:item];
}

- (BOOL)recycleItems:(const NSArray<Node *> *)items {
    return [self.theSafe recycleItems:items];
}

- (BOOL)recycleItems:(const NSArray<Node *> *)items undoData:(NSArray<NodeHierarchyReconstructionData *> * _Nullable __autoreleasing *)undoData {
    return [self.theSafe recycleItems:items undoData:undoData];
}

- (void)undoRecycle:(NSArray<NodeHierarchyReconstructionData *> *)undoData {
    [self.theSafe undoRecycle:undoData];
}

/////////////////////////////////////////////////////////////////////////////////////////////
// Moves

- (BOOL)validateMoveItems:(const NSArray<Node *> *)items destination:(Node *)destination {
    return [self.theSafe validateMoveItems:items destination:destination keePassGroupTitleRules:self.format != kPasswordSafe];
}

- (BOOL)moveItems:(const NSArray<Node *> *)items destination:(Node*)destination {
    return [self.theSafe moveItems:items destination:destination keePassGroupTitleRules:self.format != kPasswordSafe];
}

- (BOOL)moveItems:(const NSArray<Node *> *)items destination:(Node *)destination undoData:(NSArray<NodeHierarchyReconstructionData *> * _Nullable __autoreleasing *)undoData {
    return [self.theSafe moveItems:items destination:destination keePassGroupTitleRules:self.format != kPasswordSafe undoData:undoData];
}

- (void)undoMove:(NSArray<NodeHierarchyReconstructionData *> *)undoData {
    [self.theSafe undoMove:undoData];
}

////////////////////////////////////////////////////////////////////////////////////////////
// Add

- (BOOL)validateAddChild:(Node *)item destination:(Node *)destination {
    return [self.theSafe validateAddChild:item destination:destination keePassGroupTitleRules:self.format != kPasswordSafe];
}

- (BOOL)addChild:(Node *)item destination:(Node *)destination {
    return [self.theSafe addChild:item destination:destination keePassGroupTitleRules:self.format != kPasswordSafe];
}

- (void)unAddChild:(Node *)item {
    return [self.theSafe unAddChild:item];
}

////////////////////////////////////////////////////////////////////////////////////////////
// Convenience

- (NSArray<Node *>*)allNodes {
    return [self.rootGroup filterChildren:YES predicate:nil];
}

-(NSArray<Node *> *)allRecords {
    return [self.rootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return !node.isGroup;
    }];
}

-(NSArray<Node *> *)allGroups {
    return [self.rootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return node.isGroup;
    }];
}

- (NSArray<Node *> *)activeGroups {
    if(self.format == kPasswordSafe) {
        return self.allGroups;
    }
    else if(self.format == kKeePass1) {
        // Filter Backup Group
        return [self.rootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
            return node.isGroup && (self.keePass1BackupNode == nil || (node != self.keePass1BackupNode && ![self.keePass1BackupNode contains:node]));
        }];
    }
    else {
        // Filter Recycle Bin
        Node* recycleBin = self.recycleBinNode;
        
        return [self.rootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
            return node.isGroup && (recycleBin == nil || (node != recycleBin && ![recycleBin contains:node]));
        }];
    }
}

- (NSArray<Node *> *)activeRecords {
    if(self.format == kPasswordSafe) {
        return self.allRecords;
    }
    else if(self.format == kKeePass1) {
        // Filter Backup Group
        return [self.rootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
            return !node.isGroup && (self.keePass1BackupNode == nil || ![self.keePass1BackupNode contains:node]);
        }];
    }
    else {
        // Filter Recycle Bin
        Node* recycleBin = self.recycleBinNode;
        
        return [self.rootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
            return !node.isGroup && (recycleBin == nil || ![recycleBin contains:node]);
        }];
    }
}

- (NSSet<NSString*> *)urlSet {
    NSMutableSet<NSString*> *bag = [[NSMutableSet alloc]init];
    
    for (Node *recordNode in self.activeRecords) {
        if ([Utils trim:recordNode.fields.url].length > 0) {
            [bag addObject:recordNode.fields.url];
        }
    }
    
    return bag;
}

- (NSSet<NSString*> *)usernameSet {
    NSMutableSet<NSString*> *bag = [[NSMutableSet alloc]init];
    
    for (Node *recordNode in self.activeRecords) {
        if ([Utils trim:recordNode.fields.username].length > 0) {
            [bag addObject:recordNode.fields.username];
        }
    }
    
    return bag;
}

- (NSSet<NSString*> *)tagSet {
    NSArray<NSString*>* allTags = [self.activeRecords flatMap:^NSArray * _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.fields.tags.allObjects;
    }];

    NSArray<NSString*>* trimmed = [allTags map:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
        return [Utils trim:obj];
    }];

    NSArray* filtered = [trimmed filter:^BOOL(NSString * _Nonnull obj) {
        return obj.length > 0;
    }];

    return [NSSet setWithArray:filtered];
}

- (NSSet<NSString*> *)emailSet {
    NSMutableSet<NSString*> *bag = [[NSMutableSet alloc]init];
    
    for (Node *record in self.activeRecords) {
        if ([Utils trim:record.fields.email].length > 0) {
            [bag addObject:record.fields.email];
        }
    }
    
    return bag;
}

- (NSSet<NSString*> *)passwordSet {
    NSMutableSet<NSString*> *bag = [[NSMutableSet alloc]init];
    
    for (Node *record in self.activeRecords) {
        if ([Utils trim:record.fields.password].length > 0) {
            [bag addObject:record.fields.password];
        }
    }
    
    return bag;
}

- (NSString *)mostPopularEmail {
    NSCountedSet<NSString*> *bag = [[NSCountedSet alloc]init];
    
    for (Node *record in self.activeRecords) {
        if(record.fields.email.length) {
            [bag addObject:record.fields.email];
        }
    }
    
    return [self mostFrequentInCountedSet:bag];
}

- (NSString *)mostPopularUsername {
    NSCountedSet<NSString*> *bag = [[NSCountedSet alloc]init];
    
    for (Node *record in self.activeRecords) {
        if(record.fields.username.length) {
            [bag addObject:record.fields.username];
        }
    }
    
    return [self mostFrequentInCountedSet:bag];
}

- (NSString *)mostPopularPassword {
    NSCountedSet<NSString*> *bag = [[NSCountedSet alloc]init];
    
    for (Node *record in self.activeRecords) {
        [bag addObject:record.fields.password];
    }
    
    return [self mostFrequentInCountedSet:bag];
}

-(NSInteger)numberOfRecords {
    return self.allRecords.count;
}

-(NSInteger)numberOfGroups {
    return self.allGroups.count;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString*)mostFrequentInCountedSet:(NSCountedSet<NSString*>*)bag {
    NSString *mostOccurring = nil;
    NSUInteger highest = 0;
    
    for (NSString *s in bag) {
        if ([bag countForObject:s] > highest) {
            highest = [bag countForObject:s];
            mostOccurring = s;
        }
    }
    
    return mostOccurring;
}

- (BOOL)isTitleMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference {
    NSString* foo = [self maybeDeref:node.title node:node maybe:dereference];
    return [foo localizedStandardContainsString:searchText];
}

- (BOOL)isUsernameMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference {
    NSString* foo = [self maybeDeref:node.fields.username node:node maybe:dereference];
    return [foo localizedStandardContainsString:searchText];
}

- (BOOL)isPasswordMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference {
    NSString* foo = [self maybeDeref:node.fields.password node:node maybe:dereference];
    return [foo localizedStandardContainsString:searchText];
}

- (BOOL)isTagsMatches:(NSString*)searchText node:(Node*)node {
    return [node.fields.tags.allObjects anyMatch:^BOOL(NSString * _Nonnull obj) {
        return [obj localizedStandardContainsString:searchText];
    }];
}

- (BOOL)isUrlMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference {
    NSString* foo = [self maybeDeref:node.fields.url node:node maybe:dereference];
    if([foo localizedStandardContainsString:searchText]) {
        return YES;
    }

    for (NSString* altUrl in node.fields.alternativeUrls) {
        NSString* foo = [self maybeDeref:altUrl node:node maybe:dereference];
        if([foo localizedStandardContainsString:searchText]) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)isAllFieldsMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference {
    NSString* title = [self maybeDeref:node.title node:node maybe:dereference];
    NSString* username = [self maybeDeref:node.fields.username node:node maybe:dereference];
    NSString* password = [self maybeDeref:node.fields.password node:node maybe:dereference];
    NSString* url = [self maybeDeref:node.fields.url node:node maybe:dereference];
    NSString* email = [self maybeDeref:node.fields.email node:node maybe:dereference];
    NSString* notes = [self maybeDeref:node.fields.notes node:node maybe:dereference];
    
    BOOL simple =   [title localizedStandardContainsString:searchText] ||
    [username localizedStandardContainsString:searchText] ||
    [password localizedStandardContainsString:searchText] ||
    [email localizedStandardContainsString:searchText] ||
    [url localizedStandardContainsString:searchText] ||
    [notes localizedStandardContainsString:searchText];
    
    if(simple) {
        return YES;
    }
    else {
        if (self.format == kKeePass4 || self.format == kKeePass) {
            // Tags
            
            for (NSString* tag in node.fields.tags) {
                if ([tag localizedStandardContainsString:searchText]) {
                    return YES;
                }
            }

            // Custom Fields
            
            for (NSString* key in node.fields.customFields.allKeys) {
                NSString* value = node.fields.customFields[key].value;
                NSString* derefed = [self maybeDeref:value node:node maybe:dereference];
                
                if ([key localizedStandardContainsString:searchText] || [derefed localizedStandardContainsString:searchText]) {
                    return YES;
                }
            }
        }
        
        if (self.format != kPasswordSafe) {
            BOOL attachmentMatch = [node.fields.attachments anyMatch:^BOOL(NodeFileAttachment* _Nonnull obj) {
                return [obj.filename localizedStandardContainsString:searchText];
            }];
            
            if (attachmentMatch) {
                return YES;
            }
        }
    }
    
    return NO;
}

- (NSArray<NSString*>*)getSearchTerms:(NSString *)searchText {
    NSArray* split = [searchText componentsSeparatedByString:@" "];
    NSMutableSet<NSString*>* unique = [NSMutableSet setWithArray:split];
    [unique removeObject:@""];
    
    // Split into words and sort by longest word first to eliminate most entries...
    
    return [unique.allObjects sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [@(((NSString*)obj2).length) compare:@(((NSString*)obj1).length)];
    }];
}

- (CompositeKeyFactors *)compositeKeyFactors {
    return self.theSafe.compositeKeyFactors;
}

- (NSString*)getHtmlPrintString:(NSString*)databaseName {
    // MMcG: This isn't great - in future use a css resource file and find a better way to build this... functional for now.
    NSString* stylesheet = @"<head><style type=\"text/css\"> \
    body { width: 800px; } \
    .database-title { font-size: 36pt; text-align: center; } \
    .group-title { font-size: 20pt; margin-top:20px; margin-bottom: 5px; text-align: center; font-weight: bold; } \
    .entry-table {  border-collapse: collapse; margin-bottom: 10px; width: 800px; border: 1px solid black; } \
    .entry-title { font-weight: bold; font-size: 16pt; padding: 5px; } \
    table td, table th { border: 1px solid black; } \
    .entry-field-label { width: 100px; padding: 2px; } \
    .entry-field-value { font-family: Menlo; padding: 2px; max-width: 700px; word-wrap: break-word; } \
    </style></head>";
    
    NSMutableString* ret = [NSMutableString stringWithFormat:@"<html>%@\n<body>\n    <h1 class=\"database-title\">%@</h1>\n<h6>Printed: %@</h6>    ", stylesheet, [self htmlStringFromString:databaseName], NSDate.date.iso8601DateString];
    
    NSArray<Node*>* sortedGroups = [self.rootGroup.allChildGroups sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        NSString* path1 = [self getGroupPathDisplayString:obj1];
        NSString* path2 = [self getGroupPathDisplayString:obj2];
        return finderStringCompare(path1, path2);
    }];
    
    NSMutableArray* allGroups = sortedGroups.mutableCopy;
    [allGroups addObject:self.rootGroup];
    
    for(Node* group in allGroups) {
        [ret appendFormat:@"    <div class=\"group-title\">%@</div>\n", [self htmlStringFromString:[self getGroupPathDisplayString:group]]];
        
        NSMutableArray* nodeStrings = @[].mutableCopy;
        
        NSArray* sorted = [group.childRecords sortedArrayUsingComparator:finderStyleNodeComparator];
        
        for(Node* entry in sorted) {
            NSString* nodeString = [self getHtmlStringForNode:entry];
            [nodeStrings addObject:nodeString];
        }
        
        NSString* groupString = [nodeStrings componentsJoinedByString:@"\n    "];
        
        [ret appendString:groupString];
        [ret appendString:@"    </tr>\n"];
    }
    
    [ret appendString:@"</body>\n</html>"];
    return ret.copy;
}

- (NSString*)getHtmlStringForNode:(Node*)entry {
    NSMutableString* str = [NSMutableString string];
    
    [str appendFormat:@"        <table class=\"entry-table\"><tr class=\"entry-title\"><td colspan=\"100\">%@</td></tr>\n", entry.title];
    
    if(entry.fields.username.length) {
        [str appendString:[self getHtmlEntryFieldRow:@"Username" value:entry.fields.username]];
        [str appendString:@"\n"];
    }
    
    [str appendString:[self getHtmlEntryFieldRow:@"Password" value:entry.fields.password]];
    [str appendString:@"\n"];

    if(entry.fields.url.length) {
        [str appendString:[self getHtmlEntryFieldRow:@"URL" value:entry.fields.url]];
        [str appendString:@"\n"];
    }
    
    if (self.format == kPasswordSafe && entry.fields.email.length) {
        [str appendString:[self getHtmlEntryFieldRow:@"Email" value:entry.fields.email]];
        [str appendString:@"\n"];
    }
    
    if (entry.fields.notes.length) {
        [str appendString:[self getHtmlEntryFieldRow:@"Notes" value:entry.fields.notes]];
        [str appendString:@"\n"];
    }
    
    // Expiry
    
    if(entry.fields.expires) {
        [str appendString:[self getHtmlEntryFieldRow:@"Expires" value:entry.fields.expires.iso8601DateString]];
        [str appendString:@"\n"];
    }

    // Custom Fields
    
    if(entry.fields.customFields.count) {
        for (NSString* key in entry.fields.customFields.allKeys) {
            StringValue* v = entry.fields.customFields[key];
            [str appendString:[self getHtmlEntryFieldRow:key value:v.value]];
            [str appendString:@"\n"];
        }
    }
    
    [str appendString:@"</table>\n"];
    
    return str.copy;
}

- (NSString*)getHtmlEntryFieldRow:(NSString*)label value:(NSString*)value {
    return [NSString stringWithFormat:@"        <tr class=\"entry-field-row\"><td class=\"entry-field-label\">%@</td><td class = \"entry-field-value\">%@</td></tr>", label, [self htmlStringFromString:value]];
}

- (NSString*)htmlStringFromString:(NSString*)str {
    NSXMLNode *textNode = [NSXMLNode textWithStringValue:str];
    NSString *escapedString = textNode.XMLString;
    
    return [[escapedString stringByReplacingOccurrencesOfString:@"\r\n" withString:@"<br>"] stringByReplacingOccurrencesOfString:@"\n" withString:@"<br>"];
}

@end
