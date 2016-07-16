/* Copyright (c) 2013 Google Inc.
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
//  GTLDriveRevision.m
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
//   GTLDriveRevision (0 custom class methods, 18 custom properties)
//   GTLDriveRevisionExportLinks (0 custom class methods, 0 custom properties)

#import "GTLDriveRevision.h"

#import "GTLDriveUser.h"

// ----------------------------------------------------------------------------
//
//   GTLDriveRevision
//

@implementation GTLDriveRevision
@dynamic downloadUrl, ETag, exportLinks, fileSize, identifier, kind,
         lastModifyingUser, lastModifyingUserName, md5Checksum, mimeType,
         modifiedDate, originalFilename, pinned, publishAuto, published,
         publishedLink, publishedOutsideDomain, selfLink;

+ (NSDictionary *)propertyToJSONKeyMap {
  NSDictionary *map =
    [NSDictionary dictionaryWithObjectsAndKeys:
      @"etag", @"ETag",
      @"id", @"identifier",
      nil];
  return map;
}

+ (void)load {
  [self registerObjectClassForKind:@"drive#revision"];
}

@end


// ----------------------------------------------------------------------------
//
//   GTLDriveRevisionExportLinks
//

@implementation GTLDriveRevisionExportLinks

+ (Class)classForAdditionalProperties {
  return [NSString class];
}

@end
