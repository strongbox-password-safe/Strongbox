//
//  Header.h
//  Strongbox
//
//  Created by Mark on 23/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#ifndef Header_h
#define Header_h

#import "SBLog.h"

static const uint32_t kInnerStreamPlainText = 0;
static const uint32_t kInnerStreamArc4 = 1;
static const uint32_t kInnerStreamSalsa20 = 2;
static const uint32_t kInnerStreamChaCha20 = 3;

static NSString* const kLastModificationTimeElementName = @"LastModificationTime";
static NSString* const kCreationTimeElementName = @"CreationTime";
static NSString* const kExpiryTimeElementName = @"ExpiryTime";
static NSString* const kExpiresElementName = @"Expires";
static NSString* const kLastAccessTimeElementName = @"LastAccessTime";
static NSString* const kUsageCountElementName = @"UsageCount";
static NSString* const kLocationChangedTimeElementName = @"LocationChanged";
static NSString* const kDeletionTimeElementName = @"DeletionTime";

static NSString* const kDeletedObjectElementName = @"DeletedObject";
static NSString* const kDeletedObjectsElementName = @"DeletedObjects";

static NSString* const kMetaElementName = @"Meta";
static NSString* const kRootElementName = @"Root";
static NSString* const kGroupElementName = @"Group";
static NSString* const kEntryElementName = @"Entry";
static NSString* const kNameElementName = @"Name";
static NSString* const kIconIdElementName = @"IconID";
static NSString* const kCustomIconUuidElementName = @"CustomIconUUID";
static NSString* const kTagsElementName = @"Tags";
static NSString* const kIsExpandedElementName = @"IsExpanded";

static NSString* const kUuidElementName = @"UUID";
static NSString* const kTimesElementName = @"Times";

static NSString* const kGeneratorElementName = @"Generator";

static NSString* const kHistoryMaxItemsElementName = @"HistoryMaxItems";
static NSString* const kHistoryMaxSizeElementName = @"HistoryMaxSize";

static NSString* const kHeaderHashElementName = @"HeaderHash";
static NSString* const kKeePassFileElementName = @"KeePassFile";
static NSString* const kStringElementName = @"String";
static NSString* const kV3BinariesListElementName = @"Binaries";
static NSString* const kBinaryElementName = @"Binary";
static NSString* const kKeyElementName = @"Key";
static NSString* const kValueElementName = @"Value";
static NSString* const kHistoryElementName = @"History";

static NSString* const kBinaryValueAttributeRef = @"Ref";
static NSString* const kCustomIconListElementName = @"CustomIcons";
static NSString* const kCustomIconElementName = @"Icon";
static NSString* const kCustomIconDataElementName = @"Data";
static NSString* const kAttributeProtected = @"Protected";

static NSString* const kAttributeValueTrue = @"True";
static NSString* const kAttributeValueFalse = @"False";

static NSString* const kCustomDataElementName = @"CustomData";
static NSString* const kCustomDataItemElementName = @"Item";
static NSString* const kNotesElementName = @"Notes";

static NSString* const kSettingsChangedElementName = @"SettingsChanged";
static NSString* const kDatabaseNameElementName = @"DatabaseName";
static NSString* const kDatabaseNameChangedElementName = @"DatabaseNameChanged";
static NSString* const kDatabaseDescriptionElementName = @"DatabaseDescription";
static NSString* const kDatabaseDescriptionChangedElementName = @"DatabaseDescriptionChanged";
static NSString* const kDefaultUserNameElementName = @"DefaultUserName";
static NSString* const kDefaultUserNameChangedElementName = @"DefaultUserNameChanged";
static NSString* const kColorElementName = @"Color";
static NSString* const kEntryTemplatesGroupElementName = @"EntryTemplatesGroup";
static NSString* const kEntryTemplatesGroupChangedElementName = @"EntryTemplatesGroupChanged";
static NSString* const kMaintenanceHistoryDaysElementName = @"MaintenanceHistoryDays";
static NSString* const kMasterKeyChangedElementName = @"MasterKeyChanged";
static NSString* const kMasterKeyChangeRecElementName = @"MasterKeyChangeRec";
static NSString* const kMasterKeyChangeForceElementName = @"MasterKeyChangeForce";
static NSString* const kMasterKeyChangeForceOnceElementName = @"MasterKeyChangeForceOnce";
static NSString* const kLastSelectedGroupElementName = @"LastSelectedGroup";
static NSString* const kLastTopVisibleGroupElementName = @"LastTopVisibleGroup";

static NSString* const kMemoryProtectionElementName = @"MemoryProtection";

static NSString* const kProtectTitleElementName =    @"ProtectTitle";
static NSString* const kProtectUsernameElementName = @"ProtectUserName";
static NSString* const kProtectPasswordElementName = @"ProtectPassword";
static NSString* const kProtectURLElementName =      @"ProtectURL";
static NSString* const kProtectNotesElementName =    @"ProtectNotes";

static NSString* const kDefaultAutoTypeSequenceElementName = @"DefaultAutoTypeSequence";
static NSString* const kEnableAutoTypeElementName = @"EnableAutoType";
static NSString* const kEnableSearchingElementName = @"EnableSearching";
static NSString* const kLastTopVisibleElementName = @"LastTopVisibleEntry";

static NSString* const kAutoTypeAssociationElementName = @"Association";
static NSString* const kAutoTypeElementName = @"AutoType";

static NSString* const kEnabledElementName = @"Enabled";
static NSString* const kDataTransferObfuscationElementName = @"DataTransferObfuscation";
static NSString* const kAssociationElementName = @"Association";
static NSString* const kDefaultSequenceElementName = @"DefaultSequence";
static NSString* const kForegroundColorElementName = @"ForegroundColor";
static NSString* const kBackgroundColorElementName = @"BackgroundColor";
static NSString* const kOverrideURLElementName = @"OverrideURL";
static NSString* const kQualityCheckElementName = @"QualityCheck";
static NSString* const kPreviousParentGroupElementName = @"PreviousParentGroup";

static NSString* const kWindowElementName = @"Window";
static NSString* const kKeystrokeSequenceElementName = @"KeystrokeSequence";

static NSString* const kBinaryCompressedAttribute = @"Compressed";
static NSString* const kBinaryIdAttribute = @"ID";

static NSString* const kDefaultRootGroupName = @"Database";
static NSString* const kStrongboxGenerator = @"Strongbox";

static const uint32_t kNoCompressionFlag = 0;
static const uint32_t kGzipCompressionFlag = 1;

static const uint32_t kMasterSeedLength = 32;
static const uint32_t kDefaultTransformSeedLength = 32;

static NSString* const kEndOfHeaderEntriesMagicString = @"\r\n\r\n"; 

static const uint64_t kDefaultBlockifySize = 1 << 20; 

static NSString* const kKdfParametersKeyUuid = @"$UUID";

static const uint32_t kDefaultTransformRounds = 1000000;

static const int kFlagsSha2 = 1;
static const int kFlagsAes = 2;
static const int kFlagsTwoFish = 8;

static const NSInteger kDefaultHistoryMaxItems = 10;
static const NSInteger kDefaultHistoryMaxSize = 6 * 1024 * 1024;

static NSString* const kRecycleBinChangedElementName = @"RecycleBinChanged";
static NSString* const kRecycleBinEnabledElementName = @"RecycleBinEnabled";
static NSString* const kRecycleBinGroupElementName = @"RecycleBinUUID";

#endif /* Header_h */
