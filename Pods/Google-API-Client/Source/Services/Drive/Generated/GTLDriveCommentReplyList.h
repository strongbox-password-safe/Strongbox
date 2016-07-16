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
//  GTLDriveCommentReplyList.h
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
//   GTLDriveCommentReplyList (0 custom class methods, 5 custom properties)

#if GTL_BUILT_AS_FRAMEWORK
  #import "GTL/GTLObject.h"
#else
  #import "GTLObject.h"
#endif

@class GTLDriveCommentReply;

// ----------------------------------------------------------------------------
//
//   GTLDriveCommentReplyList
//

// A JSON representation of a list of replies to a comment on a file in Google
// Drive.

// This class supports NSFastEnumeration over its "items" property. It also
// supports -itemAtIndex: to retrieve individual objects from "items".

@interface GTLDriveCommentReplyList : GTLCollectionObject

// List of reply.
@property (retain) NSArray *items;  // of GTLDriveCommentReply

// This is always drive#commentReplyList.
@property (copy) NSString *kind;

// A link to the next page of replies.
@property (copy) NSString *nextLink;

// The token to use to request the next page of results.
@property (copy) NSString *nextPageToken;

// A link back to this list.
@property (copy) NSString *selfLink;

@end
