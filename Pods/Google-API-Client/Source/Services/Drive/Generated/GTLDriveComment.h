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
//  GTLDriveComment.h
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
//   GTLDriveComment (0 custom class methods, 15 custom properties)
//   GTLDriveCommentContext (0 custom class methods, 2 custom properties)

#if GTL_BUILT_AS_FRAMEWORK
  #import "GTL/GTLObject.h"
#else
  #import "GTLObject.h"
#endif

@class GTLDriveCommentContext;
@class GTLDriveCommentReply;
@class GTLDriveUser;

// ----------------------------------------------------------------------------
//
//   GTLDriveComment
//

// A JSON representation of a comment on a file in Google Drive.

@interface GTLDriveComment : GTLObject

// A region of the document represented as a JSON string. See anchor
// documentation for details on how to define and interpret anchor properties.
@property (copy) NSString *anchor;

// The user who wrote this comment.
@property (retain) GTLDriveUser *author;

// The ID of the comment.
@property (copy) NSString *commentId;

// The plain text content used to create this comment. This is not HTML safe and
// should only be used as a starting point to make edits to a comment's content.
@property (copy) NSString *content;

// The context of the file which is being commented on.
@property (retain) GTLDriveCommentContext *context;

// The date when this comment was first created.
@property (retain) GTLDateTime *createdDate;

// Whether this comment has been deleted. If a comment has been deleted the
// content will be cleared and this will only represent a comment that once
// existed.
@property (retain) NSNumber *deleted;  // boolValue

// The file which this comment is addressing.
@property (copy) NSString *fileId;

// The title of the file which this comment is addressing.
@property (copy) NSString *fileTitle;

// HTML formatted content for this comment.
@property (copy) NSString *htmlContent;

// This is always drive#comment.
@property (copy) NSString *kind;

// The date when this comment or any of its replies were last modified.
@property (retain) GTLDateTime *modifiedDate;

// Replies to this post.
@property (retain) NSArray *replies;  // of GTLDriveCommentReply

// A link back to this comment.
@property (copy) NSString *selfLink;

// The status of this comment. Status can be changed by posting a reply to a
// comment with the desired status.
// - "open" - The comment is still open.
// - "resolved" - The comment has been resolved by one of its replies.
@property (copy) NSString *status;

@end


// ----------------------------------------------------------------------------
//
//   GTLDriveCommentContext
//

@interface GTLDriveCommentContext : GTLObject

// The MIME type of the context snippet.
@property (copy) NSString *type;

// Data representation of the segment of the file being commented on. In the
// case of a text file for example, this would be the actual text that the
// comment is about.
@property (copy) NSString *value;

@end
