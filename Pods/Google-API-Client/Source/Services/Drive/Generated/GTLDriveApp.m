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
//  GTLDriveApp.m
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
//   GTLDriveApp (0 custom class methods, 24 custom properties)
//   GTLDriveAppIconsItem (0 custom class methods, 3 custom properties)

#import "GTLDriveApp.h"

// ----------------------------------------------------------------------------
//
//   GTLDriveApp
//

@implementation GTLDriveApp
@dynamic authorized, createInFolderTemplate, createUrl, hasDriveWideScope,
         icons, identifier, installed, kind, longDescription, name, objectType,
         openUrlTemplate, primaryFileExtensions, primaryMimeTypes, productId,
         productUrl, secondaryFileExtensions, secondaryMimeTypes,
         shortDescription, supportsCreate, supportsImport, supportsMultiOpen,
         supportsOfflineCreate, useByDefault;

+ (NSDictionary *)propertyToJSONKeyMap {
  NSDictionary *map =
    [NSDictionary dictionaryWithObject:@"id"
                                forKey:@"identifier"];
  return map;
}

+ (NSDictionary *)arrayPropertyToClassMap {
  NSDictionary *map =
    [NSDictionary dictionaryWithObjectsAndKeys:
      [GTLDriveAppIconsItem class], @"icons",
      [NSString class], @"primaryFileExtensions",
      [NSString class], @"primaryMimeTypes",
      [NSString class], @"secondaryFileExtensions",
      [NSString class], @"secondaryMimeTypes",
      nil];
  return map;
}

+ (void)load {
  [self registerObjectClassForKind:@"drive#app"];
}

@end


// ----------------------------------------------------------------------------
//
//   GTLDriveAppIconsItem
//

@implementation GTLDriveAppIconsItem
@dynamic category, iconUrl, size;
@end
