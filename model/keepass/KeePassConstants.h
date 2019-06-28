//
//  Header.h
//  Strongbox
//
//  Created by Mark on 23/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#ifndef Header_h
#define Header_h

static const uint32_t kInnerStreamPlainText = 0;
static const uint32_t kInnerStreamArc4 = 1;
static const uint32_t kInnerStreamSalsa20 = 2;
static const uint32_t kInnerStreamChaCha20 = 3;

static NSString* const kLastModificationTimeElementName = @"LastModificationTime";
static NSString* const kCreationTimeElementName = @"CreationTime";
static NSString* const kExpiryTimeElementName = @"ExpiryTime";
static NSString* const kExpiresElementName = @"Expires";
static NSString* const kLastAccessTimeElementName = @"LastAccessTime";
static NSString* const kMetaElementName = @"Meta";
static NSString* const kRootElementName = @"Root";
static NSString* const kGroupElementName = @"Group";
static NSString* const kEntryElementName = @"Entry";
static NSString* const kNameElementName = @"Name";
static NSString* const kIconIdElementName = @"IconID";
static NSString* const kCustomIconUuidElementName = @"CustomIconUUID";
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

static NSString* const kBinaryCompressedAttribute = @"Compressed";
static NSString* const kBinaryIdAttribute = @"ID";

static NSString* const kDefaultRootGroupName = @"Database";
static NSString* const kStrongboxGenerator = @"Strongbox";

static const uint32_t kNoCompressionFlag = 0;
static const uint32_t kGzipCompressionFlag = 1;

static const uint32_t kMasterSeedLength = 32;
static const uint32_t kDefaultTransformSeedLength = 32;

static NSString* const kEndOfHeaderEntriesMagicString = @"\r\n\r\n"; // Not sure why they bother with this, maybe to spot it in a plain text editor? Let's Cargo cult it...

static const uint64_t kDefaultBlockifySize = 1 << 20; // 1 MB seems to be the Keepass Default

static NSString* const kKdfParametersKeyUuid = @"$UUID";

static const uint32_t kDefaultTransformRounds = 600000;

static const int kFlagsSha2 = 1;
static const int kFlagsAes = 2;
static const int kFlagsTwoFish = 8;

static const NSInteger kDefaultHistoryMaxItems = 10;
static const NSInteger kDefaultHistoryMaxSize = 6 * 1024 * 1024;

static NSString* const kRecycleBinChangedElementName = @"RecycleBinChanged";
static NSString* const kRecycleBinEnabledElementName = @"RecycleBinEnabled";
static NSString* const kRecycleBinGroupElementName = @"RecycleBinUUID";

#endif /* Header_h */
