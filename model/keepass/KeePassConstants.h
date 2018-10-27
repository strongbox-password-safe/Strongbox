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
static const uint32_t kInnerChaCha20 = 3;

static NSString* const kLastModificationTimeElementName = @"LastModificationTime";
static NSString* const kCreationTimeElementName = @"CreationTime";
static NSString* const kLastAccessTimeElementName = @"LastAccessTime";
static NSString* const kMetaElementName = @"Meta";
static NSString* const kRootElementName = @"Root";
static NSString* const kGroupElementName = @"Group";
static NSString* const kEntryElementName = @"Entry";
static NSString* const kNameElementName = @"Name";
static NSString* const kUuidElementName = @"UUID";
static NSString* const kTimesElementName = @"Times";
static NSString* const kGeneratorElementName = @"Generator";
static NSString* const kHeaderHashElementName = @"HeaderHash";
static NSString* const kKeePassFileElementName = @"KeePassFile";
static NSString* const kStringElementName = @"String";
static NSString* const kKeyElementName = @"Key";
static NSString* const kValueElementName = @"Value";

static NSString* const kAttributeProtected = @"Protected";
static NSString* const kAttributeValueTrue = @"True";

static NSString* const kDefaultRootGroupName = @"Database";
static NSString* const kDefaultGenerator = @"Strongbox";

static const uint32_t kNoCompressionFlag = 0;
static const uint32_t kGzipCompressionFlag = 1;

#endif /* Header_h */
