//
//  Utils.h
//  MacBox
//
//  Created by Mark on 16/08/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>

#define ColorFromRGB(rgbValue) \
[UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 \
green:((float)((rgbValue & 0x00FF00) >>  8))/255.0 \
blue:((float)((rgbValue & 0x0000FF) >>  0))/255.0 \
alpha:1.0]

#else
#import <Cocoa/Cocoa.h>

#define ColorFromRGB(rgbValue) \
[NSColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 \
green:((float)((rgbValue & 0x00FF00) >>  8))/255.0 \
blue:((float)((rgbValue & 0x0000FF) >>  0))/255.0 \
alpha:1.0]

#endif

NS_ASSUME_NONNULL_BEGIN

@interface Utils : NSObject

+ (NSError *)createNSError:(NSString *)description errorCode:(NSInteger)errorCode;
+ (NSString *)getAppName;
+ (NSString *)getAppVersion;
+ (NSString *)getAppBuildNumber;
+ (NSString *)getAppBundleId;
+ (NSString *)insertTimestampInFilename:(NSString *)title;
+ (nullable NSString *)hostname;
+ (NSString *)getUsername;

NSString*_Nullable keePassStringIdFromUuid(NSUUID* uuid);
NSUUID*_Nullable uuidFromKeePassStringId(NSString* stringId);

BOOL isValidUrl(NSString* urlString);
NSString* trim(NSString* str);
+ (NSString *)trim:(NSString*)string;

+ (NSString*)formatTimeInterval:(NSInteger)seconds;

NSString* friendlyFileSizeString(long long byteCount);
NSString* friendlyMemorySizeString(long long byteCount);

extern NSComparator finderStringComparator;
NSComparisonResult finderStringCompare(NSString* string1, NSString* string2);

+ (void)integerTolittleEndian4Bytes:(int)data bytes:(unsigned char *)b;

NSData* Int64ToLittleEndianData(int64_t integer);
NSData* Int32ToLittleEndianData(int32_t integer);
NSData* Int16ToLittleEndianData(int16_t integer);

NSData* Uint64ToLittleEndianData(uint64_t integer);
NSData* Uint32ToLittleEndianData(uint32_t integer);
NSData* Uint16ToLittleEndianData(uint16_t integer);

int64_t littleEndian8BytesToInt64(uint8_t* bytes);
int32_t littleEndian4BytesToInt32(uint8_t* bytes);
int16_t littleEndian2BytesToInt16(uint8_t *bytes);

uint64_t littleEndian8BytesToUInt64(uint8_t* bytes);
uint32_t littleEndian4BytesToUInt32(uint8_t* bytes);
uint16_t littleEndian2BytesToUInt16(uint8_t *bytes);

int64_t littleEndianNBytesToInt64(uint8_t* bytes, int n);

void hexdump(unsigned char *buffer, unsigned long index, unsigned long width);

NSString*_Nullable sha1Base64String(NSString *string);
NSData* hmacSha1(NSData *data, NSData* key);
NSData*_Nullable getRandomData(uint32_t length);
uint32_t getRandomUint32(void);

#if TARGET_OS_IPHONE
UIImage* scaleImage(UIImage* image, CGSize newSize);

+ (UIImage *)getQrCode:(NSString *)string pointSize:(NSUInteger)pointSize;

#else
NSImage* scaleImage(NSImage* image, CGSize newSize);
#endif

#if TARGET_OS_IPHONE
+ (nullable NSData*)getImageDataFromPickedImage:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info error:(NSError**)error;
#endif

NSString* localizedYesOrNoFromBool(BOOL george);

NS_ASSUME_NONNULL_END

@end
