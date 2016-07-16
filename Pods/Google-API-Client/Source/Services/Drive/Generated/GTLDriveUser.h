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
//  GTLDriveUser.h
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

#if GTL_BUILT_AS_FRAMEWORK
  #import "GTL/GTLObject.h"
#else
  #import "GTLObject.h"
#endif

@class GTLDriveUserPicture;

// ----------------------------------------------------------------------------
//
//   GTLDriveUser
//

// The JSON template for a user.

@interface GTLDriveUser : GTLObject

// A plain text displayable name for this user.
@property (copy) NSString *displayName;

// The email address of the user.
@property (copy) NSString *emailAddress;

// Whether this user is the same as the authenticated user for whom the request
// was made.
@property (retain) NSNumber *isAuthenticatedUser;  // boolValue

// This is always drive#user.
@property (copy) NSString *kind;

// The user's ID as visible in the permissions collection.
@property (copy) NSString *permissionId;

// The user's profile picture.
@property (retain) GTLDriveUserPicture *picture;

@end


// ----------------------------------------------------------------------------
//
//   GTLDriveUserPicture
//

@interface GTLDriveUserPicture : GTLObject

// A URL that points to a profile picture of this user.
@property (copy) NSString *url;

@end
