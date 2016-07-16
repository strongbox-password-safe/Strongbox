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
//  GTLDriveApp.h
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

#if GTL_BUILT_AS_FRAMEWORK
  #import "GTL/GTLObject.h"
#else
  #import "GTLObject.h"
#endif

@class GTLDriveAppIconsItem;

// ----------------------------------------------------------------------------
//
//   GTLDriveApp
//

// The apps resource provides a list of the apps that a user has installed, with
// information about each app's supported MIME types, file extensions, and other
// details.

@interface GTLDriveApp : GTLObject

// Whether the app is authorized to access data on the user's Drive.
@property (retain) NSNumber *authorized;  // boolValue

// The template url to create a new file with this app in a given folder. The
// template will contain {folderId} to be replaced by the folder to create the
// new file in.
@property (copy) NSString *createInFolderTemplate;

// The url to create a new file with this app.
@property (copy) NSString *createUrl;

// Whether the app has drive-wide scope. An app with drive-wide scope can access
// all files in the user's drive.
@property (retain) NSNumber *hasDriveWideScope;  // boolValue

// The various icons for the app.
@property (retain) NSArray *icons;  // of GTLDriveAppIconsItem

// The ID of the app.
// identifier property maps to 'id' in JSON (to avoid Objective C's 'id').
@property (copy) NSString *identifier;

// Whether the app is installed.
@property (retain) NSNumber *installed;  // boolValue

// This is always drive#app.
@property (copy) NSString *kind;

// A long description of the app.
@property (copy) NSString *longDescription;

// The name of the app.
@property (copy) NSString *name;

// The type of object this app creates (e.g. Chart). If empty, the app name
// should be used instead.
@property (copy) NSString *objectType;

// The template url for opening files with this app. The template will contain
// {ids} and/or {exportIds} to be replaced by the actual file ids.
@property (copy) NSString *openUrlTemplate;

// The list of primary file extensions.
@property (retain) NSArray *primaryFileExtensions;  // of NSString

// The list of primary mime types.
@property (retain) NSArray *primaryMimeTypes;  // of NSString

// The ID of the product listing for this app.
@property (copy) NSString *productId;

// A link to the product listing for this app.
@property (copy) NSString *productUrl;

// The list of secondary file extensions.
@property (retain) NSArray *secondaryFileExtensions;  // of NSString

// The list of secondary mime types.
@property (retain) NSArray *secondaryMimeTypes;  // of NSString

// A short description of the app.
@property (copy) NSString *shortDescription;

// Whether this app supports creating new objects.
@property (retain) NSNumber *supportsCreate;  // boolValue

// Whether this app supports importing Google Docs.
@property (retain) NSNumber *supportsImport;  // boolValue

// Whether this app supports opening more than one file.
@property (retain) NSNumber *supportsMultiOpen;  // boolValue

// Whether this app supports creating new files when offline.
@property (retain) NSNumber *supportsOfflineCreate;  // boolValue

// Whether the app is selected as the default handler for the types it supports.
@property (retain) NSNumber *useByDefault;  // boolValue

@end


// ----------------------------------------------------------------------------
//
//   GTLDriveAppIconsItem
//

@interface GTLDriveAppIconsItem : GTLObject

// Category of the icon. Allowed values are:
// - application - icon for the application
// - document - icon for a file associated with the app
// - documentShared - icon for a shared file associated with the app
@property (copy) NSString *category;

// URL for the icon.
@property (copy) NSString *iconUrl;

// Size of the icon. Represented as the maximum of the width and height.
@property (retain) NSNumber *size;  // intValue

@end
