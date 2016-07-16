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
//  GTLDriveChannel.h
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
//   GTLDriveChannel (0 custom class methods, 10 custom properties)
//   GTLDriveChannelParams (0 custom class methods, 0 custom properties)

#if GTL_BUILT_AS_FRAMEWORK
  #import "GTL/GTLObject.h"
#else
  #import "GTLObject.h"
#endif

@class GTLDriveChannelParams;

// ----------------------------------------------------------------------------
//
//   GTLDriveChannel
//

// An notification channel used to watch for resource changes.

@interface GTLDriveChannel : GTLObject

// The address where notifications are delivered for this channel.
@property (copy) NSString *address;

// Date and time of notification channel expiration, expressed as a Unix
// timestamp, in milliseconds. Optional.
@property (retain) NSNumber *expiration;  // longLongValue

// A UUID or similar unique string that identifies this channel.
// identifier property maps to 'id' in JSON (to avoid Objective C's 'id').
@property (copy) NSString *identifier;

// Identifies this as a notification channel used to watch for changes to a
// resource. Value: the fixed string "api#channel".
@property (copy) NSString *kind;

// Additional parameters controlling delivery channel behavior. Optional.
@property (retain) GTLDriveChannelParams *params;

// A Boolean value to indicate whether payload is wanted. Optional.
@property (retain) NSNumber *payload;  // boolValue

// An opaque ID that identifies the resource being watched on this channel.
// Stable across different API versions.
@property (copy) NSString *resourceId;

// A version-specific identifier for the watched resource.
@property (copy) NSString *resourceUri;

// An arbitrary string delivered to the target address with each notification
// delivered over this channel. Optional.
@property (copy) NSString *token;

// The type of delivery mechanism used for this channel.
@property (copy) NSString *type;

@end


// ----------------------------------------------------------------------------
//
//   GTLDriveChannelParams
//

@interface GTLDriveChannelParams : GTLObject
// This object is documented as having more properties that are NSString. Use
// -additionalJSONKeys and -additionalPropertyForName: to get the list of
// properties and then fetch them; or -additionalProperties to fetch them all at
// once.
@end
