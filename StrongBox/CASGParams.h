//
//  CreateAddSetCreds.h
//  Strongbox
//
//  Created by Mark on 01/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AbstractDatabaseFormatAdaptor.h"
#import "YubiKeyHardwareConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@interface CASGParams : NSObject

@property (nullable) NSString* name;
@property (nullable) NSString* password;
@property (nullable) NSString* keyFileBookmark;
@property (nullable) NSString* keyFileFileName;
@property (nullable) YubiKeyHardwareConfiguration* yubiKeyConfig;
@property (nullable) NSData* oneTimeKeyFileData;
@property DatabaseFormat format;
@property BOOL readOnly;
@property BOOL renameFileToMatch;

@end

NS_ASSUME_NONNULL_END
