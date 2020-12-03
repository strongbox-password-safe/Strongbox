//
//  Field.h
//  StrongBox
//
//  Created by Mark McGuill on 10/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM (NSUInteger, HeaderFieldType) {
    HDR_VERSION               = 0x00,
    HDR_UUID                  = 0x01,
    HDR_NDPREFS               = 0x02,
    HDR_DISPSTAT              = 0x03,
    HDR_LASTUPDATETIME        = 0x04,
    HDR_LASTUPDATEUSERHOST    = 0x05,     
    HDR_LASTUPDATEAPPLICATION = 0x06,
    HDR_LASTUPDATEUSER        = 0x07,     
    HDR_LASTUPDATEHOST        = 0x08,     
    HDR_DBNAME                = 0x09,     
    HDR_DBDESC                = 0x0a,     
    HDR_FILTERS               = 0x0b,     
    HDR_RESERVED1             = 0x0c,     
    HDR_RESERVED2             = 0x0d,     
    HDR_RESERVED3             = 0x0e,     
    HDR_RUE                   = 0x0f,     
    HDR_PSWDPOLICIES          = 0x10,     
    HDR_EMPTYGROUP            = 0x11,     
    HDR_YUBI_SK               = 0x12,     
    HDR_LAST,                             
    HDR_END                   = 0xff
};    

typedef NS_ENUM (NSUInteger, FieldType) {
    FIELD_TYPE_START      = 0x00,
    FIELD_TYPE_GROUPTITLE = 0x00 /* reusing depreciated NAME for Group.Title combination */,
    FIELD_TYPE_NAME       = 0x00,
    FIELD_TYPE_UUID       = 0x01,
    FIELD_TYPE_GROUP      = 0x02,
    FIELD_TYPE_TITLE      = 0x03,
    FIELD_TYPE_USER       = 0x04,
    FIELD_TYPE_NOTES      = 0x05,
    FIELD_TYPE_PASSWORD   = 0x06,
    FIELD_TYPE_CTIME      = 0x07, 
    FIELD_TYPE_PMTIME     = 0x08, 
    FIELD_TYPE_ATIME      = 0x09, 
    FIELD_TYPE_XTIME      = 0x0a, 
    FIELD_TYPE_RESERVED   = 0x0b /* cannot use */,
    FIELD_TYPE_RMTIME     = 0x0c, 
    FIELD_TYPE_URL        = 0x0d,
    FIELD_TYPE_AUTOTYPE   = 0x0e,
    FIELD_TYPE_PWHIST     = 0x0f,
    FIELD_TYPE_POLICY     = 0x10, 
    FIELD_TYPE_XTIME_INT  = 0x11,
    FIELD_TYPE_RUNCMD     = 0x12,
    FIELD_TYPE_DCA        = 0x13, 
    FIELD_TYPE_EMAIL      = 0x14,
    FIELD_TYPE_PROTECTED  = 0x15,
    FIELD_TYPE_SYMBOLS    = 0x16, 
    FIELD_TYPE_SHIFTDCA   = 0x17, 
    FIELD_TYPE_POLICYNAME = 0x18, 
    FIELD_TYPE_KBSHORTCUT = 0x19, 
    FIELD_TYPE_LAST,        
    FIELD_TYPE_END        = 0xff,
};

@interface Field : NSObject

- (Field *)initEmptyDbHeaderField:(HeaderFieldType)type;
- (Field *)initNewDbHeaderField:(HeaderFieldType)type withString:(NSString *)string;
- (Field *)initNewDbHeaderField:(HeaderFieldType)type withData:(NSData *)data;
- (Field *)initEmptyWithType:(FieldType)type;
- (Field *)initWithData:(NSData *)data type:(FieldType)type;


- (void)setDataWithString:(NSString *)string;
- (void)setDataWithData:(NSData *)data;

@property (readonly) NSData *data;
@property (readonly) NSString *dataAsString;
@property (readonly) NSDate *dataAsDate;
@property (readonly) NSUUID *dataAsUuid;

@property (readonly) FieldType type;
@property (readonly) HeaderFieldType dbHeaderFieldType;
@property (readonly) NSString *prettyTypeString;
@property (readonly) NSString *prettyDataString;

+ (NSString *)prettyTypeString:(NSUInteger)type isHeaderField:(BOOL)isHeaderField;

@end
