//
//  Utils.m
//  MacBox
//
//  Created by Mark on 16/08/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "Utils.h"
#import <CommonCrypto/CommonCrypto.h>
#import "NSData+Extensions.h"
#import "NSString+Extensions.h"

#if TARGET_OS_IPHONE
#import <MobileCoreServices/MobileCoreServices.h>
#endif

@implementation Utils

BOOL isValidUrl(NSString* urlString) {
    NSString *target = trim(urlString);
    if(!target.length) {
        return NO;
    }
    
    NSError *error;
    NSDataDetector* detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:&error];

    if(detector) {
        NSRange range =[detector rangeOfFirstMatchInString:target options:NSMatchingAnchored range:NSMakeRange(0, [target length])];
        return range.location == 0 && range.length == target.length;
    }

    return NO;
}

+ (NSError *)createNSError:(NSString *)description errorCode:(NSInteger)errorCode {
    NSArray *keys = @[NSLocalizedDescriptionKey];
    NSArray *values = @[description];
    NSDictionary *userDict = [NSDictionary dictionaryWithObjects:values forKeys:keys];
    NSError *error = [[NSError alloc] initWithDomain:@"com.markmcguill.strongbox." code:errorCode userInfo:(userDict)];
    
    return error;
}

+ (NSString *)getAppBundleId {
    NSDictionary *info = [NSBundle mainBundle].infoDictionary;
    
    NSString* bundleId = info[@"CFBundleIdentifier"];

    return bundleId ? bundleId : @"";
}

+ (NSString *)getAppVersion {
    NSDictionary *info = [NSBundle mainBundle].infoDictionary;
    return [NSString stringWithFormat:@"%@", info[@"CFBundleShortVersionString"]];
}

+ (NSString *)getAppBuildNumber {
    NSDictionary *info = [NSBundle mainBundle].infoDictionary;
    return info[@"CFBundleVersion"];
}

+ (NSString *)getAppName {
    NSDictionary *info = [NSBundle mainBundle].infoDictionary;
    NSString *appName = [NSString stringWithFormat:@"%@ v%@", info[@"CFBundleName"], info[@"CFBundleShortVersionString"]];
    
    return appName;
}

+ (NSString *)insertTimestampInFilename:(NSString *)title {
    NSString *fn = title;
    
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    
    dateFormat.dateFormat = @"yyyyMMdd-HHmmss";
    NSDate *date = [[NSDate alloc] init];
    
    NSString *extension = title.pathExtension;
    fn = [NSString stringWithFormat:@"%@-%@.%@", title, [dateFormat stringFromDate:date], extension];
    
    return fn;
}

+ (NSString *)hostname {
#if TARGET_OS_IPHONE
    char baseHostName[256];
    int success = gethostname(baseHostName, 255);
    if (success != 0) {
        return nil;
    }
    baseHostName[255] = '\0';
    return [NSString stringWithFormat:@"%s", baseHostName];
#else
    return [[NSHost currentHost] localizedName];
#endif
}










+ (NSString*)getUsername {
    return NSFullUserName();
}

+ (NSString*)formatTimeInterval:(NSInteger)seconds {
    if(seconds == 0) {
        return NSLocalizedString(@"prefs_vc_time_interval_none", @"None");
    }
    
    NSDateComponentsFormatter* fmt =  [[NSDateComponentsFormatter alloc] init];
    
    fmt.allowedUnits =  NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
    fmt.unitsStyle = NSDateComponentsFormatterUnitsStyleShort;
    
    return [fmt stringFromTimeInterval:seconds];
}

NSString* friendlyFileSizeString(long long byteCount) {
    return [NSByteCountFormatter stringFromByteCount:byteCount countStyle:NSByteCountFormatterCountStyleFile];
}

NSString* friendlyMemorySizeString(long long byteCount) {
    return [NSByteCountFormatter stringFromByteCount:byteCount countStyle:NSByteCountFormatterCountStyleMemory];
}

NSString* keePassStringIdFromUuid(NSUUID* uuid) {
    if (!uuid) {
        return nil;
    }
    
    
    uuid_t uid;
    [uuid getUUIDBytes:(uint8_t*)&uid];
    
    return [NSData dataWithBytes:uid length:sizeof(uuid_t)].hexString;
}

NSUUID* uuidFromKeePassStringId(NSString* stringId) {
    if(stringId.length != 32) {
        return nil;
    }
    
    
    
    NSData* uuidData = stringId.dataFromHex;
    return [[NSUUID alloc] initWithUUIDBytes:uuidData.bytes];
}

NSString* trim(NSString* str) {
    return [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

+(NSString *)trim:(NSString*)string {
    return trim(string);
}

NSComparator finderStringComparator = ^(id obj1, id obj2)
{
    return finderStringCompare(obj1, obj2);
};

+ (NSComparisonResult)finderStringCompare:(NSString*)string1 string2:(NSString*)string2
{
    return finderStringCompare(string1, string2);
}

NSComparisonResult finderStringCompare(NSString* string1, NSString* string2) {
    
    
    
    static NSStringCompareOptions comparisonOptions =
    NSCaseInsensitiveSearch | NSNumericSearch |
    NSWidthInsensitiveSearch | NSForcedOrderingSearch;
    
    NSRange string1Range = NSMakeRange(0, [string1 length]);
    
    return [string1 compare:string2
                    options:comparisonOptions
                      range:string1Range
                     locale:[NSLocale currentLocale]];
};


+ (void)integerTolittleEndian4Bytes:(int)data bytes:(unsigned char *)b {
    b[0] = (unsigned char)data;
    b[1] = (unsigned char)(((uint)data >> 8) & 0xFF);
    b[2] = (unsigned char)(((uint)data >> 16) & 0xFF);
    b[3] = (unsigned char)(((uint)data >> 24) & 0xFF);
}

NSData* Int64ToLittleEndianData(int64_t integer) {
    return IntToLittleEndianData(integer, 8);
}

NSData* Int32ToLittleEndianData(int32_t integer) {
    return IntToLittleEndianData(integer, 4);
}

NSData* Int16ToLittleEndianData(int16_t integer) {
    return IntToLittleEndianData(integer, 2);
}

NSData* Uint64ToLittleEndianData(uint64_t integer) {
    return UintToLittleEndianData(integer, 8);
}

NSData* Uint32ToLittleEndianData(uint32_t integer) {
    return UintToLittleEndianData(integer, 4);
}

NSData* Uint16ToLittleEndianData(uint16_t integer) {
    return UintToLittleEndianData(integer, 2);
}

int64_t littleEndian8BytesToInt64(uint8_t* bytes) {
    return littleEndianNBytesToInt64(bytes, 8);
}

int32_t littleEndian4BytesToInt32(uint8_t* bytes) {
    int32_t ret = (int32_t)littleEndianNBytesToInt64(bytes, 4);
    
    return ret;
}

int16_t littleEndian2BytesToInt16(uint8_t *bytes) {
    int16_t ret = (int16_t)littleEndianNBytesToInt64(bytes, 2);
    
    return ret;
}

uint64_t littleEndian8BytesToUInt64(uint8_t* bytes) {
    uint64_t ret = (uint64_t)littleEndianNBytesToInt64(bytes, 8);
    return ret;
}

uint32_t littleEndian4BytesToUInt32(uint8_t* bytes) {
    uint32_t ret = (uint32_t)littleEndianNBytesToInt64(bytes, 4);
    return ret;
}

uint16_t littleEndian2BytesToUInt16(uint8_t *bytes) {
    uint16_t ret = (uint16_t)littleEndianNBytesToInt64(bytes, 2);
    
    return ret;
}

int64_t littleEndianNBytesToInt64(uint8_t* bytes, int n)  {
    if(n > 8) {
        NSLog(@"n > 8 passed to littleEndianNBytesToInt64");
        return -1;
    }
    
    int64_t ret = 0;
    
    for (int i=0; i<n; i++) {
        int64_t tmp = bytes[i];
        ret |= tmp << (i*8);
    }
    
    return ret;
}

NSData* UintToLittleEndianData(uint64_t integer, uint8_t byteCount) {
    NSMutableData *ret = [[NSMutableData alloc] initWithLength:byteCount];
    
    for(int i=0;i<byteCount;i++) {
        ((uint8_t*)ret.mutableBytes)[i] = (uint8_t)(((uint64_t)integer >> (i * 8)) & 0xFF);
    }
    
    return ret;
}

NSData* IntToLittleEndianData(int64_t integer, uint8_t byteCount) {
    NSMutableData *ret = [[NSMutableData alloc] initWithLength:byteCount];
    
    for(int i=0;i<byteCount;i++) {
        ((uint8_t*)ret.mutableBytes)[i] = (uint8_t)(((int64_t)integer >> (i * 8)) & 0xFF);
    }
    
    return ret;
}



void hexdump(unsigned char *buffer, unsigned long index, unsigned long width) {
    unsigned long i;
    
    for (i = 0; i < index; i++) {
        printf("%02x ", buffer[i]);
    }
    
    for (unsigned long spacer = index; spacer < width; spacer++) {
        printf("    ");
    }
    
    printf(": ");
    
    for (i = 0; i < index; i++) {
        if (!isprint(buffer[i])) printf(".");
        else printf("%c", buffer[i]);
    }
    
    printf("\n");
}

NSData* hmacSha1(NSData* data, NSData* key) {
    unsigned char cHMAC[CC_SHA1_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA1, key.bytes, key.length, data.bytes, data.length, cHMAC);
    return [[NSData alloc] initWithBytes:cHMAC length:CC_SHA1_DIGEST_LENGTH];
}

uint32_t getRandomUint32() {
    uint32_t ret;
    if(SecRandomCopyBytes(kSecRandomDefault, sizeof(uint32_t), &ret))
    {
        NSLog(@"Could not securely copy new random bytes");
        return -1;
    }
    
    return ret;
}

NSData* getRandomData(uint32_t length) {
    NSMutableData *start = [NSMutableData dataWithLength:length];
    if(SecRandomCopyBytes(kSecRandomDefault, length, start.mutableBytes))
    {
        NSLog(@"Could not securely copy new random bytes");
        return nil;
    }
    
    return start;
}

#if TARGET_OS_IPHONE
UIImage* scaleImage(UIImage* image, CGSize newSize) {
    float heightToWidthRatio = image.size.height / image.size.width;
    float scaleFactor = 1;
    if(heightToWidthRatio > 1) {
        scaleFactor = newSize.height / image.size.height;
    } else {
        scaleFactor = newSize.width / image.size.width;
    }
    
    CGSize newSize2 = newSize;
    newSize2.width = image.size.width * scaleFactor;
    newSize2.height = image.size.height * scaleFactor;
    
    @autoreleasepool { 
        UIGraphicsBeginImageContext(newSize2);
        [image drawInRect:CGRectMake(0,0,newSize2.width,newSize2.height)];
        UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
   
        return newImage;
    }
}
#else
NSImage* scaleImage(NSImage* image, CGSize newSize) {
    if (!image || !image.isValid) {
        return image;
    }
    
    float heightToWidthRatio = image.size.height / image.size.width;
    float scaleFactor = 1;
    if(heightToWidthRatio > 1) {
        scaleFactor = newSize.height / image.size.height;
    } else {
        scaleFactor = newSize.width / image.size.width;
    }
    
    CGSize newSize2 = newSize;
    newSize2.width = image.size.width * scaleFactor;
    newSize2.height = image.size.height * scaleFactor;

    NSImage *ret = [[NSImage alloc] initWithSize:newSize2];
    if (!ret || !ret.isValid) {
        return image;
    }
    [ret lockFocus];
    
    NSRect thumbnailRect = { 0 };
    
    thumbnailRect.size.width = newSize2.width;
    thumbnailRect.size.height = newSize2.height;
    
    [image drawInRect:thumbnailRect
             fromRect:NSZeroRect
            operation:NSCompositingOperationSourceOver
             fraction:1.0];
    
    [ret unlockFocus];
    
    return ret;
}

#endif

#if TARGET_OS_IPHONE
+ (NSData*)getImageDataFromPickedImage:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info error:(NSError**)error {
    NSString* mediaType = [info objectForKey:UIImagePickerControllerMediaType];
    BOOL isImage = UTTypeConformsTo((__bridge CFStringRef)mediaType, kUTTypeImage) != 0;
    
    NSURL *url;
    NSData* data;
    
    if(isImage) {
        if (@available(iOS 11.0, *)) {
            url =  [info objectForKey:UIImagePickerControllerImageURL];
        } else {
            UIImage* image = [info objectForKey:UIImagePickerControllerOriginalImage];
            
            if(!image) {
                if(error) {
                    *error = [Utils createNSError:@"Could not read the data for this item" errorCode:-1];
                }
                return nil;
            }
            
            data = UIImagePNGRepresentation(image);
        }
    }
    else {
        url =  [info objectForKey:UIImagePickerControllerMediaURL];
    }
    
    if(url) {
        data = [NSData dataWithContentsOfURL:url options:kNilOptions error:error];
    }
    
    return data;
}

+ (UIImage *)getQrCode:(NSString *)string pointSize:(NSUInteger)pointSize {
    CIImage *input = [self createQRForString:string];

    NSUInteger kImageViewSize = pointSize * UIScreen.mainScreen.scale;
    CGFloat scale = kImageViewSize / input.extent.size.width;

    NSLog(@"Scaling by %f (image size = %lu)", scale, (unsigned long)kImageViewSize);

    CGAffineTransform transform = CGAffineTransformMakeScale(scale, scale);

    CIImage *qrCode = [input imageByApplyingTransform:transform];

    return [UIImage imageWithCIImage:qrCode
                               scale:[UIScreen mainScreen].scale
                         orientation:UIImageOrientationUp];
}

+ (CIImage *)createQRForString:(NSString *)qrString {
    NSData *stringData = [qrString dataUsingEncoding:NSISOLatin1StringEncoding];
    CIFilter *qrFilter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    
    
    
    [qrFilter setValue:stringData forKey:@"inputMessage"];
    [qrFilter setValue:@"H" forKey:@"inputCorrectionLevel"];

    return qrFilter.outputImage;
}

#endif

NSString* localizedYesOrNoFromBool(BOOL george) {
    return george ?
    NSLocalizedString(@"alerts_yes", @"Yes") :
    NSLocalizedString(@"alerts_no", @"No");
}

















    
































@end
