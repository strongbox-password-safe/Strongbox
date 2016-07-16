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
//  GTLQueryDrive.m
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
//   GTLQueryDrive (59 custom class methods, 45 custom properties)

#import "GTLQueryDrive.h"

#import "GTLDriveAbout.h"
#import "GTLDriveApp.h"
#import "GTLDriveAppList.h"
#import "GTLDriveChange.h"
#import "GTLDriveChangeList.h"
#import "GTLDriveChannel.h"
#import "GTLDriveChildList.h"
#import "GTLDriveChildReference.h"
#import "GTLDriveComment.h"
#import "GTLDriveCommentList.h"
#import "GTLDriveCommentReply.h"
#import "GTLDriveCommentReplyList.h"
#import "GTLDriveFile.h"
#import "GTLDriveFileList.h"
#import "GTLDriveParentList.h"
#import "GTLDriveParentReference.h"
#import "GTLDrivePermission.h"
#import "GTLDrivePermissionId.h"
#import "GTLDrivePermissionList.h"
#import "GTLDriveProperty.h"
#import "GTLDrivePropertyList.h"
#import "GTLDriveRevision.h"
#import "GTLDriveRevisionList.h"

@implementation GTLQueryDrive

@dynamic acknowledgeAbuse, addParents, appFilterExtensions, appFilterMimeTypes,
         appId, baseRevision, changeId, childId, commentId, convert, corpus,
         email, emailMessage, fields, fileId, folderId, includeDeleted,
         includeSubscribed, languageCode, maxChangeIdCount, maxResults,
         newRevision, ocr, ocrLanguage, pageToken, parentId, permissionId,
         pinned, projection, propertyKey, q, removeParents, replyId, revision,
         revisionId, sendNotificationEmails, setModifiedDate, startChangeId,
         timedTextLanguage, timedTextTrackName, transferOwnership, updatedMin,
         updateViewedDate, useContentAsIndexableText, visibility;

#pragma mark -
#pragma mark "about" methods
// These create a GTLQueryDrive object.

+ (id)queryForAboutGet {
  NSString *methodName = @"drive.about.get";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.expectedObjectClass = [GTLDriveAbout class];
  return query;
}

#pragma mark -
#pragma mark "apps" methods
// These create a GTLQueryDrive object.

+ (id)queryForAppsGetWithAppId:(NSString *)appId {
  NSString *methodName = @"drive.apps.get";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.appId = appId;
  query.expectedObjectClass = [GTLDriveApp class];
  return query;
}

+ (id)queryForAppsList {
  NSString *methodName = @"drive.apps.list";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.expectedObjectClass = [GTLDriveAppList class];
  return query;
}

#pragma mark -
#pragma mark "changes" methods
// These create a GTLQueryDrive object.

+ (id)queryForChangesGetWithChangeId:(NSString *)changeId {
  NSString *methodName = @"drive.changes.get";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.changeId = changeId;
  query.expectedObjectClass = [GTLDriveChange class];
  return query;
}

+ (id)queryForChangesList {
  NSString *methodName = @"drive.changes.list";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.expectedObjectClass = [GTLDriveChangeList class];
  return query;
}

+ (id)queryForChangesWatchWithObject:(GTLDriveChannel *)object {
  if (object == nil) {
    GTL_DEBUG_ASSERT(object != nil, @"%@ got a nil object", NSStringFromSelector(_cmd));
    return nil;
  }
  NSString *methodName = @"drive.changes.watch";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.bodyObject = object;
  query.expectedObjectClass = [GTLDriveChannel class];
  return query;
}

#pragma mark -
#pragma mark "channels" methods
// These create a GTLQueryDrive object.

+ (id)queryForChannelsStopWithObject:(GTLDriveChannel *)object {
  if (object == nil) {
    GTL_DEBUG_ASSERT(object != nil, @"%@ got a nil object", NSStringFromSelector(_cmd));
    return nil;
  }
  NSString *methodName = @"drive.channels.stop";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.bodyObject = object;
  return query;
}

#pragma mark -
#pragma mark "children" methods
// These create a GTLQueryDrive object.

+ (id)queryForChildrenDeleteWithFolderId:(NSString *)folderId
                                 childId:(NSString *)childId {
  NSString *methodName = @"drive.children.delete";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.folderId = folderId;
  query.childId = childId;
  return query;
}

+ (id)queryForChildrenGetWithFolderId:(NSString *)folderId
                              childId:(NSString *)childId {
  NSString *methodName = @"drive.children.get";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.folderId = folderId;
  query.childId = childId;
  query.expectedObjectClass = [GTLDriveChildReference class];
  return query;
}

+ (id)queryForChildrenInsertWithObject:(GTLDriveChildReference *)object
                              folderId:(NSString *)folderId {
  if (object == nil) {
    GTL_DEBUG_ASSERT(object != nil, @"%@ got a nil object", NSStringFromSelector(_cmd));
    return nil;
  }
  NSString *methodName = @"drive.children.insert";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.bodyObject = object;
  query.folderId = folderId;
  query.expectedObjectClass = [GTLDriveChildReference class];
  return query;
}

+ (id)queryForChildrenListWithFolderId:(NSString *)folderId {
  NSString *methodName = @"drive.children.list";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.folderId = folderId;
  query.expectedObjectClass = [GTLDriveChildList class];
  return query;
}

#pragma mark -
#pragma mark "comments" methods
// These create a GTLQueryDrive object.

+ (id)queryForCommentsDeleteWithFileId:(NSString *)fileId
                             commentId:(NSString *)commentId {
  NSString *methodName = @"drive.comments.delete";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.fileId = fileId;
  query.commentId = commentId;
  return query;
}

+ (id)queryForCommentsGetWithFileId:(NSString *)fileId
                          commentId:(NSString *)commentId {
  NSString *methodName = @"drive.comments.get";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.fileId = fileId;
  query.commentId = commentId;
  query.expectedObjectClass = [GTLDriveComment class];
  return query;
}

+ (id)queryForCommentsInsertWithObject:(GTLDriveComment *)object
                                fileId:(NSString *)fileId {
  if (object == nil) {
    GTL_DEBUG_ASSERT(object != nil, @"%@ got a nil object", NSStringFromSelector(_cmd));
    return nil;
  }
  NSString *methodName = @"drive.comments.insert";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.bodyObject = object;
  query.fileId = fileId;
  query.expectedObjectClass = [GTLDriveComment class];
  return query;
}

+ (id)queryForCommentsListWithFileId:(NSString *)fileId {
  NSString *methodName = @"drive.comments.list";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.fileId = fileId;
  query.expectedObjectClass = [GTLDriveCommentList class];
  return query;
}

+ (id)queryForCommentsPatchWithObject:(GTLDriveComment *)object
                               fileId:(NSString *)fileId
                            commentId:(NSString *)commentId {
  if (object == nil) {
    GTL_DEBUG_ASSERT(object != nil, @"%@ got a nil object", NSStringFromSelector(_cmd));
    return nil;
  }
  NSString *methodName = @"drive.comments.patch";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.bodyObject = object;
  query.fileId = fileId;
  query.commentId = commentId;
  query.expectedObjectClass = [GTLDriveComment class];
  return query;
}

+ (id)queryForCommentsUpdateWithObject:(GTLDriveComment *)object
                                fileId:(NSString *)fileId
                             commentId:(NSString *)commentId {
  if (object == nil) {
    GTL_DEBUG_ASSERT(object != nil, @"%@ got a nil object", NSStringFromSelector(_cmd));
    return nil;
  }
  NSString *methodName = @"drive.comments.update";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.bodyObject = object;
  query.fileId = fileId;
  query.commentId = commentId;
  query.expectedObjectClass = [GTLDriveComment class];
  return query;
}

#pragma mark -
#pragma mark "files" methods
// These create a GTLQueryDrive object.

+ (id)queryForFilesCopyWithObject:(GTLDriveFile *)object
                           fileId:(NSString *)fileId {
  if (object == nil) {
    GTL_DEBUG_ASSERT(object != nil, @"%@ got a nil object", NSStringFromSelector(_cmd));
    return nil;
  }
  NSString *methodName = @"drive.files.copy";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.bodyObject = object;
  query.fileId = fileId;
  query.expectedObjectClass = [GTLDriveFile class];
  return query;
}

+ (id)queryForFilesDeleteWithFileId:(NSString *)fileId {
  NSString *methodName = @"drive.files.delete";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.fileId = fileId;
  return query;
}

+ (id)queryForFilesEmptyTrash {
  NSString *methodName = @"drive.files.emptyTrash";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  return query;
}

+ (id)queryForFilesGetWithFileId:(NSString *)fileId {
  NSString *methodName = @"drive.files.get";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.fileId = fileId;
  query.expectedObjectClass = [GTLDriveFile class];
  return query;
}

+ (id)queryForFilesInsertWithObject:(GTLDriveFile *)object
                   uploadParameters:(GTLUploadParameters *)uploadParametersOrNil {
  if (object == nil) {
    GTL_DEBUG_ASSERT(object != nil, @"%@ got a nil object", NSStringFromSelector(_cmd));
    return nil;
  }
  NSString *methodName = @"drive.files.insert";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.bodyObject = object;
  query.uploadParameters = uploadParametersOrNil;
  query.expectedObjectClass = [GTLDriveFile class];
  return query;
}

+ (id)queryForFilesList {
  NSString *methodName = @"drive.files.list";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.expectedObjectClass = [GTLDriveFileList class];
  return query;
}

+ (id)queryForFilesPatchWithObject:(GTLDriveFile *)object
                            fileId:(NSString *)fileId {
  if (object == nil) {
    GTL_DEBUG_ASSERT(object != nil, @"%@ got a nil object", NSStringFromSelector(_cmd));
    return nil;
  }
  NSString *methodName = @"drive.files.patch";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.bodyObject = object;
  query.fileId = fileId;
  query.expectedObjectClass = [GTLDriveFile class];
  return query;
}

+ (id)queryForFilesTouchWithFileId:(NSString *)fileId {
  NSString *methodName = @"drive.files.touch";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.fileId = fileId;
  query.expectedObjectClass = [GTLDriveFile class];
  return query;
}

+ (id)queryForFilesTrashWithFileId:(NSString *)fileId {
  NSString *methodName = @"drive.files.trash";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.fileId = fileId;
  query.expectedObjectClass = [GTLDriveFile class];
  return query;
}

+ (id)queryForFilesUntrashWithFileId:(NSString *)fileId {
  NSString *methodName = @"drive.files.untrash";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.fileId = fileId;
  query.expectedObjectClass = [GTLDriveFile class];
  return query;
}

+ (id)queryForFilesUpdateWithObject:(GTLDriveFile *)object
                             fileId:(NSString *)fileId
                   uploadParameters:(GTLUploadParameters *)uploadParametersOrNil {
  if (object == nil) {
    GTL_DEBUG_ASSERT(object != nil, @"%@ got a nil object", NSStringFromSelector(_cmd));
    return nil;
  }
  NSString *methodName = @"drive.files.update";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.bodyObject = object;
  query.fileId = fileId;
  query.uploadParameters = uploadParametersOrNil;
  query.expectedObjectClass = [GTLDriveFile class];
  return query;
}

+ (id)queryForFilesWatchWithObject:(GTLDriveChannel *)object
                            fileId:(NSString *)fileId {
  if (object == nil) {
    GTL_DEBUG_ASSERT(object != nil, @"%@ got a nil object", NSStringFromSelector(_cmd));
    return nil;
  }
  NSString *methodName = @"drive.files.watch";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.bodyObject = object;
  query.fileId = fileId;
  query.expectedObjectClass = [GTLDriveChannel class];
  return query;
}

#pragma mark -
#pragma mark "parents" methods
// These create a GTLQueryDrive object.

+ (id)queryForParentsDeleteWithFileId:(NSString *)fileId
                             parentId:(NSString *)parentId {
  NSString *methodName = @"drive.parents.delete";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.fileId = fileId;
  query.parentId = parentId;
  return query;
}

+ (id)queryForParentsGetWithFileId:(NSString *)fileId
                          parentId:(NSString *)parentId {
  NSString *methodName = @"drive.parents.get";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.fileId = fileId;
  query.parentId = parentId;
  query.expectedObjectClass = [GTLDriveParentReference class];
  return query;
}

+ (id)queryForParentsInsertWithObject:(GTLDriveParentReference *)object
                               fileId:(NSString *)fileId {
  if (object == nil) {
    GTL_DEBUG_ASSERT(object != nil, @"%@ got a nil object", NSStringFromSelector(_cmd));
    return nil;
  }
  NSString *methodName = @"drive.parents.insert";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.bodyObject = object;
  query.fileId = fileId;
  query.expectedObjectClass = [GTLDriveParentReference class];
  return query;
}

+ (id)queryForParentsListWithFileId:(NSString *)fileId {
  NSString *methodName = @"drive.parents.list";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.fileId = fileId;
  query.expectedObjectClass = [GTLDriveParentList class];
  return query;
}

#pragma mark -
#pragma mark "permissions" methods
// These create a GTLQueryDrive object.

+ (id)queryForPermissionsDeleteWithFileId:(NSString *)fileId
                             permissionId:(NSString *)permissionId {
  NSString *methodName = @"drive.permissions.delete";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.fileId = fileId;
  query.permissionId = permissionId;
  return query;
}

+ (id)queryForPermissionsGetWithFileId:(NSString *)fileId
                          permissionId:(NSString *)permissionId {
  NSString *methodName = @"drive.permissions.get";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.fileId = fileId;
  query.permissionId = permissionId;
  query.expectedObjectClass = [GTLDrivePermission class];
  return query;
}

+ (id)queryForPermissionsGetIdForEmailWithEmail:(NSString *)email {
  NSString *methodName = @"drive.permissions.getIdForEmail";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.email = email;
  query.expectedObjectClass = [GTLDrivePermissionId class];
  return query;
}

+ (id)queryForPermissionsInsertWithObject:(GTLDrivePermission *)object
                                   fileId:(NSString *)fileId {
  if (object == nil) {
    GTL_DEBUG_ASSERT(object != nil, @"%@ got a nil object", NSStringFromSelector(_cmd));
    return nil;
  }
  NSString *methodName = @"drive.permissions.insert";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.bodyObject = object;
  query.fileId = fileId;
  query.expectedObjectClass = [GTLDrivePermission class];
  return query;
}

+ (id)queryForPermissionsListWithFileId:(NSString *)fileId {
  NSString *methodName = @"drive.permissions.list";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.fileId = fileId;
  query.expectedObjectClass = [GTLDrivePermissionList class];
  return query;
}

+ (id)queryForPermissionsPatchWithObject:(GTLDrivePermission *)object
                                  fileId:(NSString *)fileId
                            permissionId:(NSString *)permissionId {
  if (object == nil) {
    GTL_DEBUG_ASSERT(object != nil, @"%@ got a nil object", NSStringFromSelector(_cmd));
    return nil;
  }
  NSString *methodName = @"drive.permissions.patch";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.bodyObject = object;
  query.fileId = fileId;
  query.permissionId = permissionId;
  query.expectedObjectClass = [GTLDrivePermission class];
  return query;
}

+ (id)queryForPermissionsUpdateWithObject:(GTLDrivePermission *)object
                                   fileId:(NSString *)fileId
                             permissionId:(NSString *)permissionId {
  if (object == nil) {
    GTL_DEBUG_ASSERT(object != nil, @"%@ got a nil object", NSStringFromSelector(_cmd));
    return nil;
  }
  NSString *methodName = @"drive.permissions.update";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.bodyObject = object;
  query.fileId = fileId;
  query.permissionId = permissionId;
  query.expectedObjectClass = [GTLDrivePermission class];
  return query;
}

#pragma mark -
#pragma mark "properties" methods
// These create a GTLQueryDrive object.

+ (id)queryForPropertiesDeleteWithFileId:(NSString *)fileId
                             propertyKey:(NSString *)propertyKey {
  NSString *methodName = @"drive.properties.delete";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.fileId = fileId;
  query.propertyKey = propertyKey;
  return query;
}

+ (id)queryForPropertiesGetWithFileId:(NSString *)fileId
                          propertyKey:(NSString *)propertyKey {
  NSString *methodName = @"drive.properties.get";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.fileId = fileId;
  query.propertyKey = propertyKey;
  query.expectedObjectClass = [GTLDriveProperty class];
  return query;
}

+ (id)queryForPropertiesInsertWithObject:(GTLDriveProperty *)object
                                  fileId:(NSString *)fileId {
  if (object == nil) {
    GTL_DEBUG_ASSERT(object != nil, @"%@ got a nil object", NSStringFromSelector(_cmd));
    return nil;
  }
  NSString *methodName = @"drive.properties.insert";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.bodyObject = object;
  query.fileId = fileId;
  query.expectedObjectClass = [GTLDriveProperty class];
  return query;
}

+ (id)queryForPropertiesListWithFileId:(NSString *)fileId {
  NSString *methodName = @"drive.properties.list";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.fileId = fileId;
  query.expectedObjectClass = [GTLDrivePropertyList class];
  return query;
}

+ (id)queryForPropertiesPatchWithObject:(GTLDriveProperty *)object
                                 fileId:(NSString *)fileId
                            propertyKey:(NSString *)propertyKey {
  if (object == nil) {
    GTL_DEBUG_ASSERT(object != nil, @"%@ got a nil object", NSStringFromSelector(_cmd));
    return nil;
  }
  NSString *methodName = @"drive.properties.patch";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.bodyObject = object;
  query.fileId = fileId;
  query.propertyKey = propertyKey;
  query.expectedObjectClass = [GTLDriveProperty class];
  return query;
}

+ (id)queryForPropertiesUpdateWithObject:(GTLDriveProperty *)object
                                  fileId:(NSString *)fileId
                             propertyKey:(NSString *)propertyKey {
  if (object == nil) {
    GTL_DEBUG_ASSERT(object != nil, @"%@ got a nil object", NSStringFromSelector(_cmd));
    return nil;
  }
  NSString *methodName = @"drive.properties.update";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.bodyObject = object;
  query.fileId = fileId;
  query.propertyKey = propertyKey;
  query.expectedObjectClass = [GTLDriveProperty class];
  return query;
}

#pragma mark -
#pragma mark "realtime" methods
// These create a GTLQueryDrive object.

+ (id)queryForRealtimeGetWithFileId:(NSString *)fileId {
  NSString *methodName = @"drive.realtime.get";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.fileId = fileId;
  return query;
}

+ (id)queryForRealtimeUpdateWithFileId:(NSString *)fileId
                      uploadParameters:(GTLUploadParameters *)uploadParametersOrNil {
  NSString *methodName = @"drive.realtime.update";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.fileId = fileId;
  query.uploadParameters = uploadParametersOrNil;
  return query;
}

#pragma mark -
#pragma mark "replies" methods
// These create a GTLQueryDrive object.

+ (id)queryForRepliesDeleteWithFileId:(NSString *)fileId
                            commentId:(NSString *)commentId
                              replyId:(NSString *)replyId {
  NSString *methodName = @"drive.replies.delete";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.fileId = fileId;
  query.commentId = commentId;
  query.replyId = replyId;
  return query;
}

+ (id)queryForRepliesGetWithFileId:(NSString *)fileId
                         commentId:(NSString *)commentId
                           replyId:(NSString *)replyId {
  NSString *methodName = @"drive.replies.get";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.fileId = fileId;
  query.commentId = commentId;
  query.replyId = replyId;
  query.expectedObjectClass = [GTLDriveCommentReply class];
  return query;
}

+ (id)queryForRepliesInsertWithObject:(GTLDriveCommentReply *)object
                               fileId:(NSString *)fileId
                            commentId:(NSString *)commentId {
  if (object == nil) {
    GTL_DEBUG_ASSERT(object != nil, @"%@ got a nil object", NSStringFromSelector(_cmd));
    return nil;
  }
  NSString *methodName = @"drive.replies.insert";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.bodyObject = object;
  query.fileId = fileId;
  query.commentId = commentId;
  query.expectedObjectClass = [GTLDriveCommentReply class];
  return query;
}

+ (id)queryForRepliesListWithFileId:(NSString *)fileId
                          commentId:(NSString *)commentId {
  NSString *methodName = @"drive.replies.list";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.fileId = fileId;
  query.commentId = commentId;
  query.expectedObjectClass = [GTLDriveCommentReplyList class];
  return query;
}

+ (id)queryForRepliesPatchWithObject:(GTLDriveCommentReply *)object
                              fileId:(NSString *)fileId
                           commentId:(NSString *)commentId
                             replyId:(NSString *)replyId {
  if (object == nil) {
    GTL_DEBUG_ASSERT(object != nil, @"%@ got a nil object", NSStringFromSelector(_cmd));
    return nil;
  }
  NSString *methodName = @"drive.replies.patch";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.bodyObject = object;
  query.fileId = fileId;
  query.commentId = commentId;
  query.replyId = replyId;
  query.expectedObjectClass = [GTLDriveCommentReply class];
  return query;
}

+ (id)queryForRepliesUpdateWithObject:(GTLDriveCommentReply *)object
                               fileId:(NSString *)fileId
                            commentId:(NSString *)commentId
                              replyId:(NSString *)replyId {
  if (object == nil) {
    GTL_DEBUG_ASSERT(object != nil, @"%@ got a nil object", NSStringFromSelector(_cmd));
    return nil;
  }
  NSString *methodName = @"drive.replies.update";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.bodyObject = object;
  query.fileId = fileId;
  query.commentId = commentId;
  query.replyId = replyId;
  query.expectedObjectClass = [GTLDriveCommentReply class];
  return query;
}

#pragma mark -
#pragma mark "revisions" methods
// These create a GTLQueryDrive object.

+ (id)queryForRevisionsDeleteWithFileId:(NSString *)fileId
                             revisionId:(NSString *)revisionId {
  NSString *methodName = @"drive.revisions.delete";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.fileId = fileId;
  query.revisionId = revisionId;
  return query;
}

+ (id)queryForRevisionsGetWithFileId:(NSString *)fileId
                          revisionId:(NSString *)revisionId {
  NSString *methodName = @"drive.revisions.get";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.fileId = fileId;
  query.revisionId = revisionId;
  query.expectedObjectClass = [GTLDriveRevision class];
  return query;
}

+ (id)queryForRevisionsListWithFileId:(NSString *)fileId {
  NSString *methodName = @"drive.revisions.list";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.fileId = fileId;
  query.expectedObjectClass = [GTLDriveRevisionList class];
  return query;
}

+ (id)queryForRevisionsPatchWithObject:(GTLDriveRevision *)object
                                fileId:(NSString *)fileId
                            revisionId:(NSString *)revisionId {
  if (object == nil) {
    GTL_DEBUG_ASSERT(object != nil, @"%@ got a nil object", NSStringFromSelector(_cmd));
    return nil;
  }
  NSString *methodName = @"drive.revisions.patch";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.bodyObject = object;
  query.fileId = fileId;
  query.revisionId = revisionId;
  query.expectedObjectClass = [GTLDriveRevision class];
  return query;
}

+ (id)queryForRevisionsUpdateWithObject:(GTLDriveRevision *)object
                                 fileId:(NSString *)fileId
                             revisionId:(NSString *)revisionId {
  if (object == nil) {
    GTL_DEBUG_ASSERT(object != nil, @"%@ got a nil object", NSStringFromSelector(_cmd));
    return nil;
  }
  NSString *methodName = @"drive.revisions.update";
  GTLQueryDrive *query = [self queryWithMethodName:methodName];
  query.bodyObject = object;
  query.fileId = fileId;
  query.revisionId = revisionId;
  query.expectedObjectClass = [GTLDriveRevision class];
  return query;
}

@end
