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
//  GTLDriveComment.m
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

#import "GTLDriveComment.h"

#import "GTLDriveCommentReply.h"
#import "GTLDriveUser.h"

// ----------------------------------------------------------------------------
//
//   GTLDriveComment
//

@implementation GTLDriveComment
@dynamic anchor, author, commentId, content, context, createdDate, deleted,
         fileId, fileTitle, htmlContent, kind, modifiedDate, replies, selfLink,
         status;

+ (NSDictionary *)arrayPropertyToClassMap {
  NSDictionary *map =
    [NSDictionary dictionaryWithObject:[GTLDriveCommentReply class]
                                forKey:@"replies"];
  return map;
}

+ (void)load {
  [self registerObjectClassForKind:@"drive#comment"];
}

@end


// ----------------------------------------------------------------------------
//
//   GTLDriveCommentContext
//

@implementation GTLDriveCommentContext
@dynamic type, value;
@end
