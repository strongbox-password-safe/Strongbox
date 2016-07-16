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
//  GTLDriveConstants.h
//

// ----------------------------------------------------------------------------
// NOTE: This file is generated from Google APIs Discovery Service.
// Service:
//   Drive API (drive/v2)
// Description:
//   The API to interact with Drive.
// Documentation:
//   https://developers.google.com/drive/

#import <Foundation/Foundation.h>

#if GTL_BUILT_AS_FRAMEWORK
  #import "GTL/GTLDefines.h"
#else
  #import "GTLDefines.h"
#endif

// Authorization scope
// View and manage the files and documents in your Google Drive
GTL_EXTERN NSString * const kGTLAuthScopeDrive;                 // "https://www.googleapis.com/auth/drive"
// View and manage its own configuration data in your Google Drive
GTL_EXTERN NSString * const kGTLAuthScopeDriveAppdata;          // "https://www.googleapis.com/auth/drive.appdata"
// View your Google Drive apps
GTL_EXTERN NSString * const kGTLAuthScopeDriveAppsReadonly;     // "https://www.googleapis.com/auth/drive.apps.readonly"
// View and manage Google Drive files that you have opened or created with this
// app
GTL_EXTERN NSString * const kGTLAuthScopeDriveFile;             // "https://www.googleapis.com/auth/drive.file"
// View metadata for files and documents in your Google Drive
GTL_EXTERN NSString * const kGTLAuthScopeDriveMetadataReadonly;  // "https://www.googleapis.com/auth/drive.metadata.readonly"
// View the files and documents in your Google Drive
GTL_EXTERN NSString * const kGTLAuthScopeDriveReadonly;         // "https://www.googleapis.com/auth/drive.readonly"
// Modify your Google Apps Script scripts' behavior
GTL_EXTERN NSString * const kGTLAuthScopeDriveScripts;          // "https://www.googleapis.com/auth/drive.scripts"

// GTLQueryDrive - Corpus
GTL_EXTERN NSString * const kGTLDriveCorpusDefault;  // "DEFAULT"
GTL_EXTERN NSString * const kGTLDriveCorpusDomain;   // "DOMAIN"

// GTLQueryDrive - Projection
GTL_EXTERN NSString * const kGTLDriveProjectionBasic;  // "BASIC"
GTL_EXTERN NSString * const kGTLDriveProjectionFull;   // "FULL"

// GTLQueryDrive - Visibility
GTL_EXTERN NSString * const kGTLDriveVisibilityDefault;  // "DEFAULT"
GTL_EXTERN NSString * const kGTLDriveVisibilityPrivate;  // "PRIVATE"
