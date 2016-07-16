/* Copyright (c) 2012 Google Inc.
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
//  GTLDriveCommentReply.h
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
//   GTLDriveCommentReply (0 custom class methods, 9 custom properties)

#if GTL_BUILT_AS_FRAMEWORK
  #import "GTL/GTLObject.h"
#else
  #import "GTLObject.h"
#endif

@class GTLDriveUser;

// ----------------------------------------------------------------------------
//
//   GTLDriveCommentReply
//

// A JSON representation of a reply to a comment on a file in Google Drive.

@interface GTLDriveCommentReply : GTLObject

// The user who wrote this reply.
@property (retain) GTLDriveUser *author;

// The plain text content used to create this reply. This is not HTML safe and
// should only be used as a starting point to make edits to a reply's content.
// This field is required on inserts if no verb is specified (resolve/reopen).
@property (copy) NSString *content;

// The date when this reply was first created.
@property (retain) GTLDateTime *createdDate;

// Whether this reply has been deleted. If a reply has been deleted the content
// will be cleared and this will only represent a reply that once existed.
@property (retain) NSNumber *deleted;  // boolValue

// HTML formatted content for this reply.
@property (copy) NSString *htmlContent;

// This is always drive#commentReply.
@property (copy) NSString *kind;

// The date when this reply was last modified.
@property (retain) GTLDateTime *modifiedDate;

// The ID of the reply.
@property (copy) NSString *replyId;

// The action this reply performed to the parent comment. When creating a new
// reply this is the action to be perform to the parent comment. Possible values
// are:
// - "resolve" - To resolve a comment.
// - "reopen" - To reopen (un-resolve) a comment.
@property (copy) NSString *verb;

@end
