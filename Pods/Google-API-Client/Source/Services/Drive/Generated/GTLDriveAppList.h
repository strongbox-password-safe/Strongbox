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
//  GTLDriveAppList.h
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
//   GTLDriveAppList (0 custom class methods, 5 custom properties)

#if GTL_BUILT_AS_FRAMEWORK
  #import "GTL/GTLObject.h"
#else
  #import "GTLObject.h"
#endif

@class GTLDriveApp;

// ----------------------------------------------------------------------------
//
//   GTLDriveAppList
//

// A list of third-party applications which the user has installed or given
// access to Google Drive.

// This class supports NSFastEnumeration over its "items" property. It also
// supports -itemAtIndex: to retrieve individual objects from "items".

@interface GTLDriveAppList : GTLCollectionObject

// List of app IDs that the user has specified to use by default. The list is in
// reverse-priority order (lowest to highest).
@property (retain) NSArray *defaultAppIds;  // of NSString

// The ETag of the list.
@property (copy) NSString *ETag;

// The actual list of apps.
@property (retain) NSArray *items;  // of GTLDriveApp

// This is always drive#appList.
@property (copy) NSString *kind;

// A link back to this list.
@property (copy) NSString *selfLink;

@end
