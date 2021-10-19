//
//  Field.m
//  StrongBox
//
//  Created by Mark McGuill on 10/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "Field.h"
#import "PwSafeSerialization.h"
#import "Utils.h"

@implementation Field {
    NSData *_data;
    unsigned char _type;
    BOOL _isHeaderField;
}



- (Field *)initEmptyDbHeaderField:(HeaderFieldType)type {
    return [self initWithData:[[NSData alloc] init] type:type header:YES];
}

- (Field *)initNewDbHeaderField:(HeaderFieldType)type withString:(NSString *)string {
    return [self initWithData:[string dataUsingEncoding:NSUTF8StringEncoding] type:type header:YES];
}

- (Field *)initNewDbHeaderField:(HeaderFieldType)type withData:(NSData *)data {
    return [self initWithData:data type:type header:YES];
}

- (Field *)initEmptyWithType:(FieldType)type {
    return [self initWithData:[[NSData alloc] init] type:type header:NO];
}

- (Field *)initWithData:(NSData *)data type:(FieldType)type {
    return [self initWithData:data type:type header:NO];
}

- (Field *)initWithData:(NSData *)data type:(unsigned char)type header:(BOOL)header {
    if (self = [super init]) {
        _data = data;
        _type = type;
        _isHeaderField = header;

        return self;
    }
    else {
        return nil;
    }
}



- (NSData *)data {
    return _data;
}

- (NSString *)dataAsString {
    return [[NSString alloc]initWithData:_data encoding:NSUTF8StringEncoding];
}

- (NSUUID *)dataAsUuid {
    uuid_t uuid;
    [_data getBytes:&uuid length:sizeof(uuid_t)];
    NSUUID *u = [[NSUUID alloc] initWithUUIDBytes:uuid];

    return u;
}

+ (NSString *)dataToUUIDString:(NSData *)data {
    uuid_t uuid;
    [data getBytes:&uuid length:sizeof(uuid_t)];
    NSUUID *u = [[NSUUID alloc] initWithUUIDBytes:uuid];
    return u.UUIDString;
}

- (NSDate *)dataAsDate {
    time_t time = 0;

    [_data getBytes:&time length:sizeof(time_t)];

    return [NSDate dateWithTimeIntervalSince1970:time];
}

- (void)setDataWithData:(NSData *)data {
    if (![data isEqualToData:_data]) {
        _data = data;
    }
}

- (void)setDataWithString:(NSString *)string {
    NSData *newData = [string dataUsingEncoding:NSUTF8StringEncoding];

    if (![newData isEqualToData:_data]) {
        _data = newData;
    }
}

- (FieldType)type {
    return self->_type;
}

- (HeaderFieldType)dbHeaderFieldType {
    return self->_type;
}

- (NSString *)prettyDataString {
    if (_isHeaderField) {
        switch (self->_type) {
            case HDR_VERSION: {
                unsigned char v[2];
                [_data getBytes:v length:2];
                return [NSString stringWithFormat:@"%d.%d", v[1], v[0]];
            }

            case HDR_UUID:
                return [Field dataToUUIDString:self->_data];

                break;

            case HDR_LASTUPDATETIME:
                return [Field dateString:self.dataAsDate];

                break;

            case HDR_NDPREFS:
            case HDR_DISPSTAT:
            case HDR_LASTUPDATEUSERHOST:
            case HDR_LASTUPDATEAPPLICATION:
            case HDR_LASTUPDATEUSER:
            case HDR_LASTUPDATEHOST:
            case HDR_DBNAME:
            case HDR_DBDESC:
            case HDR_FILTERS:
            case HDR_RESERVED1:
            case HDR_RESERVED2:
            case HDR_RESERVED3:
            case HDR_RUE:
            case HDR_PSWDPOLICIES:
            case HDR_EMPTYGROUP:
            case HDR_YUBI_SK:
            case HDR_LAST:
            case HDR_END:
            default:
                return [[NSString alloc]initWithData:self->_data encoding:NSUTF8StringEncoding];

                break;
        }
    }
    else {
        switch (self->_type) {
            case FIELD_TYPE_UUID:
                return [Field dataToUUIDString:self->_data];

                break;

            case FIELD_TYPE_CTIME:       
            case FIELD_TYPE_PMTIME: 
            case FIELD_TYPE_ATIME:  
            case FIELD_TYPE_XTIME:  
            case FIELD_TYPE_RMTIME: 
                return [Field dateString:self.dataAsDate];

                break;

            case FIELD_TYPE_XTIME_INT: {
                uint32_t intervalInDays = littleEndian4BytesToUInt32((unsigned char *)self->_data.bytes);
                return intervalInDays == 0 ? @"< Not Set >" : [[NSString alloc] initWithFormat:@"%d Days", intervalInDays];
            }
                                       break;

            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            default:
                return [[NSString alloc]initWithData:self->_data encoding:NSUTF8StringEncoding];

                break;
        }
    }
}

- (NSString *)prettyTypeString {
    return [Field prettyTypeString:self.type isHeaderField:_isHeaderField];
}

+ (NSString *)prettyTypeString:(NSUInteger)type isHeaderField:(BOOL)isHeaderField  {
    NSString *ret;

    if (isHeaderField) {
        switch (type) {
            case HDR_VERSION:
                ret = @"HDR_VERSION";
                break;

            case HDR_UUID:
                ret = @"HDR_UUID";
                break;

            case HDR_NDPREFS:
                ret = @"HDR_NDPREFS";
                break;

            case HDR_DISPSTAT:
                ret = @"HDR_DISPSTAT";
                break;

            case HDR_LASTUPDATETIME:
                ret = @"HDR_LASTUPDATETIME";
                break;

            case HDR_LASTUPDATEUSERHOST:
                ret = @"HDR_LASTUPDATEUSERHOST";
                break;

            case HDR_LASTUPDATEAPPLICATION:
                ret = @"HDR_LASTUPDATEAPPLICATION";
                break;

            case HDR_LASTUPDATEUSER:
                ret = @"HDR_LASTUPDATEUSER";
                break;

            case HDR_LASTUPDATEHOST:
                ret = @"HDR_LASTUPDATEHOST";
                break;

            case HDR_DBNAME:
                ret = @"HDR_DBNAME";
                break;

            case HDR_DBDESC:
                ret = @"HDR_DBDESC";
                break;

            case HDR_FILTERS:
                ret = @"HDR_FILTERS";
                break;

            case HDR_RESERVED1:
                ret = @"HDR_RESERVED1";
                break;

            case HDR_RESERVED2:
                ret = @"HDR_RESERVED2";
                break;

            case HDR_RESERVED3:
                ret = @"HDR_RESERVED3";
                break;

            case HDR_RUE:
                ret = @"HDR_RUE";
                break;

            case HDR_PSWDPOLICIES:
                ret = @"HDR_PSWDPOLICIES";
                break;

            case HDR_EMPTYGROUP:
                ret = @"HDR_EMPTYGROUP";
                break;

            case HDR_YUBI_SK:
                ret = @"HDR_YUBI_SK";
                break;

            case HDR_LAST:
                ret = @"HDR_LAST";
                break;

            case HDR_END:
                ret = @"HDR_END";
                break;

            default:
                return @"<Unknown>"; 

                break;
        }
    }
    else {
        switch (type) {
            case FIELD_TYPE_START:
                ret = @"START";
                break;

            case FIELD_TYPE_UUID:
                ret = @"UUID";
                break;

            case FIELD_TYPE_GROUP:
                ret = @"Group";
                break;

            case FIELD_TYPE_TITLE:
                ret = @"Title";
                break;

            case FIELD_TYPE_USER:
                ret = @"Username";
                break;

            case FIELD_TYPE_NOTES:
                ret = @"Notes";
                break;

            case FIELD_TYPE_PASSWORD:
                ret = @"Password";
                break;

            case FIELD_TYPE_CTIME:
                ret = @"Created";
                break;

            case FIELD_TYPE_PMTIME:
                ret = @"Password Modified";
                break;

            case FIELD_TYPE_ATIME:
                ret = @"Accessed";
                break;

            case FIELD_TYPE_XTIME:
                ret = @"Expiry";
                break;

            case FIELD_TYPE_RESERVED:
                ret = @"RESERVED";
                break;

            case FIELD_TYPE_RMTIME:
                ret = @"Modified";
                break;

            case FIELD_TYPE_URL:
                ret = @"URL";
                break;

            case FIELD_TYPE_AUTOTYPE:
                ret = @"AUTOTYPE";
                break;

            case FIELD_TYPE_PWHIST:
                ret = @"PWHIST";
                break;

            case FIELD_TYPE_POLICY:
                ret = @"POLICY";
                break;

            case FIELD_TYPE_XTIME_INT:
                ret = @"Expiry Interval";
                break;

            case FIELD_TYPE_RUNCMD:
                ret = @"RUNCMD";
                break;

            case FIELD_TYPE_DCA:
                ret = @"DCA";
                break;

            case FIELD_TYPE_EMAIL:
                ret = @"EMAIL";
                break;

            case FIELD_TYPE_PROTECTED:
                ret = @"PROTECTED";
                break;

            case FIELD_TYPE_SYMBOLS:
                ret = @"SYMBOLS";
                break;

            case FIELD_TYPE_SHIFTDCA:
                ret = @"SHIFTDCA";
                break;

            case FIELD_TYPE_POLICYNAME:
                ret = @"POLICYNAME";
                break;

            case FIELD_TYPE_KBSHORTCUT:
                ret = @"KBSHORTCUT";
                break;

            case FIELD_TYPE_END:
                ret = @"END";
                break;

            default:
                ret = @"<Unknown>";
                break;
        }
    }

    return ret;
}

+ (NSString *)dateString:(NSDate *)date {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];

    dateFormatter.dateStyle = NSDateFormatterMediumStyle;
    dateFormatter.timeStyle = NSDateFormatterShortStyle;
    dateFormatter.locale = [NSLocale currentLocale];

    NSString *dateString = [dateFormatter stringFromDate:date];

    return dateString;
}

@end
