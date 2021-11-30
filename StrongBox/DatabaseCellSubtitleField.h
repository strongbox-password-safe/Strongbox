//
//  DatabaseCellSubtitleField.h
//  Strongbox
//
//  Created by Mark on 30/07/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#ifndef DatabaseCellSubtitleField_h
#define DatabaseCellSubtitleField_h

typedef NS_ENUM (NSInteger, DatabaseCellSubtitleField) {
    kDatabaseCellSubtitleFieldNone,
    kDatabaseCellSubtitleFieldFileName,
    kDatabaseCellSubtitleFieldStorage,
    kDatabaseCellSubtitleFieldLastModifiedDate,
    kDatabaseCellSubtitleFieldLastModifiedDatePrecise,
    kDatabaseCellSubtitleFieldFileSize,
    kDatabaseCellSubtitleFieldCreateDate,
    kDatabaseCellSubtitleFieldCreateDatePrecise,
};

#endif /* DatabaseCellSubtitleField_h */
