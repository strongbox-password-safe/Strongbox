//
//  Record.m
//  StrongBox
//
//  Created by Mark McGuill on 11/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "Record.h"
#import "Field.h"

@implementation Record {
    NSMutableDictionary *_fields;
}

- (Record *)init {
    return [self initWithFields:@{}];
}

- (Record *)initWithFields:(NSDictionary *)fds {
    if (self = [super init]) {
        _fields = [[NSMutableDictionary alloc] init];

        for (NSNumber *key in fds.allKeys) {
            Field *field = fds[key];
            NSNumber *type = @(key.intValue);

            _fields[type] = field;
        }
        
        // Give record a UUID if it's not set
        if (![self getFieldForType:FIELD_TYPE_UUID]) {
            [self generateNewUUID];
        }
        
        return self;
    }
    else {
        return nil;
    }
}

- (NSArray *)getAllFields; {
    return _fields.allValues;
}

/////////////////////////////////////////////////////////////////////////////////////////////

- (PasswordHistory *)passwordHistory {
    Field *field = [self getFieldForType:FIELD_TYPE_PWHIST];

    if (field) {
        return [[PasswordHistory alloc] initWithData:field.data];
    }

    return [[PasswordHistory alloc] init];
}

- (void)setPasswordHistory:(PasswordHistory *)passwordHistory {
    if(!passwordHistory) {
        [_fields removeObjectForKey:[NSNumber numberWithInt:FIELD_TYPE_PWHIST]];
    }
    else {
        [self setFieldWithData:FIELD_TYPE_PWHIST data:[passwordHistory getAsData]];
    }
}

- (NSDate *)accessed {
    return [self getDataAsDateForField:FIELD_TYPE_ATIME];
}

- (void)setAccessed:(NSDate *)accessed {
    [self setFieldWithDate:FIELD_TYPE_ATIME date:accessed];
}

- (NSDate *)modified {
    return [self getDataAsDateForField:FIELD_TYPE_RMTIME];
}

- (void)setModified:(NSDate *)modified {
    [self setFieldWithDate:FIELD_TYPE_RMTIME date:modified];
}

- (NSDate *)created {
    return [self getDataAsDateForField:FIELD_TYPE_CTIME];
}

- (void)setCreated:(NSDate *)created {
    [self setFieldWithDate:FIELD_TYPE_CTIME date:created];
}

- (NSDate *)passwordModified {
    return [self getDataAsDateForField:FIELD_TYPE_PMTIME];
}

- (void)setPasswordModified:(NSDate *)passwordModified {
    [self setFieldWithDate:FIELD_TYPE_PMTIME date:passwordModified];
}

- (NSString *)password {
    return [self getPrettyStringForField:FIELD_TYPE_PASSWORD];
}

- (void)setPassword:(NSString *)password {
    if ([password isEqualToString:self.password]) {
        return;
    }

    [self setField:FIELD_TYPE_PASSWORD string:password];
}

- (NSString *)title {
    return [self getPrettyStringForField:FIELD_TYPE_TITLE];
}

- (void)setTitle:(NSString *)title {
    if (![title isEqualToString:self.title]) {
        [self setField:FIELD_TYPE_TITLE
                string:title];
    }
}

- (NSString *)username {
    return [self getPrettyStringForField:FIELD_TYPE_USER];
}

- (void)setUsername:(NSString *)username {
    if (![username isEqualToString:self.username]) {
        [self setField:FIELD_TYPE_USER
                string:username];
    }
}

- (NSString *)url {
    return [self getPrettyStringForField:FIELD_TYPE_URL];
}

- (void)setUrl:(NSString *)url {
    if (![url isEqualToString:self.url]) {
        [self setField:FIELD_TYPE_URL
                string:url];
    }
}

- (NSString *)notes {
    return [self getPrettyStringForField:FIELD_TYPE_NOTES];
}

- (void)setNotes:(NSString *)notes {
    if (![notes isEqualToString:self.notes]) {
        [self setField:FIELD_TYPE_NOTES
                string:notes];
    }
}

- (NSString *)uuid {
    return [self getPrettyStringForField:FIELD_TYPE_UUID];
}

- (void)generateNewUUID {
    NSUUID *unique = [[NSUUID alloc] init];
    unsigned char bytes[16];

    [unique getUUIDBytes:bytes];
    NSData *d = [[NSData alloc] initWithBytes:bytes length:16];

    [self setFieldWithData:FIELD_TYPE_UUID data:d];
}

- (Group *)group {
    NSString *g = [self getDataAsStringForField:FIELD_TYPE_GROUP];

    return [[Group alloc] initWithEscapedPathString:g];
}

- (void)setGroup:(Group *)group {
    if (![group isEqual:self.group]) {
        [self setField:FIELD_TYPE_GROUP string:group.escapedPathString];
    }
}

/////////////////////////////////////////////////////////////////////////////////////////////

- (void)setFieldWithData:(FieldType)type data:(NSData *)data {
    Field *field = [self getFieldForType:type];

    if (!field) {
        field = [[Field alloc] initWithData:data type:type];
        _fields[[NSNumber numberWithInt:type]] = field;
    }
    else {
        [field setDataWithData:data];
    }
}

- (void)setFieldWithDate:(FieldType)type date:(NSDate *)date {
    time_t timeT = (time_t)date.timeIntervalSince1970;
    NSData *dataTime = [[NSData alloc] initWithBytes:&timeT length:4];

    [self setFieldWithData:type data:dataTime];
}

- (void)setField:(FieldType)type string:(NSString *)string {
    Field *field = [self getFieldForType:type];

    if (!field) {
        field = [[Field alloc] initEmptyWithType:type];
        _fields[[NSNumber numberWithInt:type]] = field;
    }

    [field setDataWithString:string];
}

- (NSString *)getDataAsStringForField:(FieldType)type {
    Field *field = [self getFieldForType:type];

    if (field) {
        return field.dataAsString;
    }

    return @"";
}

- (NSDate *)getDataAsDateForField:(FieldType)type {
    Field *field = [self getFieldForType:type];

    if (field) {
        return field.dataAsDate;
    }

    return nil;
}

- (NSString *)getPrettyStringForField:(FieldType)type {
    Field *field = [self getFieldForType:type];

    if (field) {
        return field.prettyDataString;
    }

    return @"";
}

- (Field *)getFieldForType:(FieldType)type {
    NSNumber *groupType = [NSNumber numberWithInt:type];

    Field *field = _fields[groupType];

    return field;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ - [group:%@] - [user: %@]", self.title, self.group, self.username];
}

@end
