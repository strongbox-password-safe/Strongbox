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
//  GTLDriveUser.m
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
//   GTLDriveUser (0 custom class methods, 6 custom properties)
//   GTLDriveUserPicture (0 custom class methods, 1 custom properties)

#import "GTLDriveUser.h"

// ----------------------------------------------------------------------------
//
//   GTLDriveUser
//

@implementation GTLDriveUser
@dynamic displayName, emailAddress, isAuthenticatedUser, kind, permissionId,
         picture;

+ (void)load {
  [self registerObjectClassForKind:@"drive#user"];
}

@end


// ----------------------------------------------------------------------------
//
//   GTLDriveUserPicture
//

@implementation GTLDriveUserPicture
@dynamic url;
@end
