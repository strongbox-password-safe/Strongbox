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
//  GTLServiceDrive.m
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
//   GTLServiceDrive (0 custom class methods, 0 custom properties)

#import "GTLDrive.h"

@implementation GTLServiceDrive

#if DEBUG
// Method compiled in debug builds just to check that all the needed support
// classes are present at link time.
+ (NSArray *)checkClasses {
  NSArray *classes = [NSArray arrayWithObjects:
                      [GTLQueryDrive class],
                      [GTLDriveAbout class],
                      [GTLDriveApp class],
                      [GTLDriveAppList class],
                      [GTLDriveChange class],
                      [GTLDriveChangeList class],
                      [GTLDriveChannel class],
                      [GTLDriveChildList class],
                      [GTLDriveChildReference class],
                      [GTLDriveComment class],
                      [GTLDriveCommentList class],
                      [GTLDriveCommentReply class],
                      [GTLDriveCommentReplyList class],
                      [GTLDriveFile class],
                      [GTLDriveFileList class],
                      [GTLDriveParentList class],
                      [GTLDriveParentReference class],
                      [GTLDrivePermission class],
                      [GTLDrivePermissionId class],
                      [GTLDrivePermissionList class],
                      [GTLDriveProperty class],
                      [GTLDrivePropertyList class],
                      [GTLDriveRevision class],
                      [GTLDriveRevisionList class],
                      [GTLDriveUser class],
                      nil];
  return classes;
}
#endif  // DEBUG

- (id)init {
  self = [super init];
  if (self) {
    // Version from discovery.
    self.apiVersion = @"v2";

    // From discovery.  Where to send JSON-RPC.
    // Turn off prettyPrint for this service to save bandwidth (especially on
    // mobile). The fetcher logging will pretty print.
    self.rpcURL = [NSURL URLWithString:@"https://www.googleapis.com/rpc?prettyPrint=false"];
    self.rpcUploadURL = [NSURL URLWithString:@"https://www.googleapis.com/upload/rpc?uploadType=resumable&prettyPrint=false"];
  }
  return self;
}

@end
