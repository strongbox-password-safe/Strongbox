/* Copyright (c) 2014 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

//
//  GTLDriveAbout.m
//

// ----------------------------------------------------------------------------
// NOTE: This file is generated from Google APIs Discovery Service.
// Service:
//   Drive API (drive/v2)
// Description:
//   The API to interact with Drive.
// Documentation:
//   https://developers.google.com/drive/
// Classes:
//   GTLDriveAbout (0 custom class methods, 23 custom properties)
//   GTLDriveAboutAdditionalRoleInfoItem (0 custom class methods, 2 custom properties)
//   GTLDriveAboutExportFormatsItem (0 custom class methods, 2 custom properties)
//   GTLDriveAboutFeaturesItem (0 custom class methods, 2 custom properties)
//   GTLDriveAboutImportFormatsItem (0 custom class methods, 2 custom properties)
//   GTLDriveAboutMaxUploadSizesItem (0 custom class methods, 2 custom properties)
//   GTLDriveAboutQuotaBytesByServiceItem (0 custom class methods, 2 custom properties)
//   GTLDriveAboutAdditionalRoleInfoItemRoleSetsItem (0 custom class methods, 2 custom properties)

#import "GTLDriveAbout.h"

#import "GTLDriveUser.h"

// ----------------------------------------------------------------------------
//
//   GTLDriveAbout
//

@implementation GTLDriveAbout
@dynamic additionalRoleInfo, domainSharingPolicy, ETag, exportFormats, features,
         importFormats, isCurrentAppInstalled, kind, languageCode,
         largestChangeId, maxUploadSizes, name, permissionId,
         quotaBytesByService, quotaBytesTotal, quotaBytesUsed,
         quotaBytesUsedAggregate, quotaBytesUsedInTrash, quotaType,
         remainingChangeIds, rootFolderId, selfLink, user;

+ (NSDictionary *)propertyToJSONKeyMap {
  NSDictionary *map =
    [NSDictionary dictionaryWithObject:@"etag"
                                forKey:@"ETag"];
  return map;
}

+ (NSDictionary *)arrayPropertyToClassMap {
  NSDictionary *map =
    [NSDictionary dictionaryWithObjectsAndKeys:
      [GTLDriveAboutAdditionalRoleInfoItem class], @"additionalRoleInfo",
      [GTLDriveAboutExportFormatsItem class], @"exportFormats",
      [GTLDriveAboutFeaturesItem class], @"features",
      [GTLDriveAboutImportFormatsItem class], @"importFormats",
      [GTLDriveAboutMaxUploadSizesItem class], @"maxUploadSizes",
      [GTLDriveAboutQuotaBytesByServiceItem class], @"quotaBytesByService",
      nil];
  return map;
}

+ (void)load {
  [self registerObjectClassForKind:@"drive#about"];
}

@end


// ----------------------------------------------------------------------------
//
//   GTLDriveAboutAdditionalRoleInfoItem
//

@implementation GTLDriveAboutAdditionalRoleInfoItem
@dynamic roleSets, type;

+ (NSDictionary *)arrayPropertyToClassMap {
  NSDictionary *map =
    [NSDictionary dictionaryWithObject:[GTLDriveAboutAdditionalRoleInfoItemRoleSetsItem class]
                                forKey:@"roleSets"];
  return map;
}

@end


// ----------------------------------------------------------------------------
//
//   GTLDriveAboutExportFormatsItem
//

@implementation GTLDriveAboutExportFormatsItem
@dynamic source, targets;

+ (NSDictionary *)arrayPropertyToClassMap {
  NSDictionary *map =
    [NSDictionary dictionaryWithObject:[NSString class]
                                forKey:@"targets"];
  return map;
}

@end


// ----------------------------------------------------------------------------
//
//   GTLDriveAboutFeaturesItem
//

@implementation GTLDriveAboutFeaturesItem
@dynamic featureName, featureRate;
@end


// ----------------------------------------------------------------------------
//
//   GTLDriveAboutImportFormatsItem
//

@implementation GTLDriveAboutImportFormatsItem
@dynamic source, targets;

+ (NSDictionary *)arrayPropertyToClassMap {
  NSDictionary *map =
    [NSDictionary dictionaryWithObject:[NSString class]
                                forKey:@"targets"];
  return map;
}

@end


// ----------------------------------------------------------------------------
//
//   GTLDriveAboutMaxUploadSizesItem
//

@implementation GTLDriveAboutMaxUploadSizesItem
@dynamic size, type;
@end


// ----------------------------------------------------------------------------
//
//   GTLDriveAboutQuotaBytesByServiceItem
//

@implementation GTLDriveAboutQuotaBytesByServiceItem
@dynamic bytesUsed, serviceName;
@end


// ----------------------------------------------------------------------------
//
//   GTLDriveAboutAdditionalRoleInfoItemRoleSetsItem
//

@implementation GTLDriveAboutAdditionalRoleInfoItemRoleSetsItem
@dynamic additionalRoles, primaryRole;

+ (NSDictionary *)arrayPropertyToClassMap {
  NSDictionary *map =
    [NSDictionary dictionaryWithObject:[NSString class]
                                forKey:@"additionalRoles"];
  return map;
}

@end
