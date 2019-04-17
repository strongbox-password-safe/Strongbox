//
//  Utils.m
//  MacBox
//
//  Created by Mark on 16/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "Utils.h"
#import <CommonCrypto/CommonCrypto.h>

#if TARGET_OS_IPHONE
#import <MobileCoreServices/MobileCoreServices.h>
#endif

@implementation Utils

+ (NSError *)createNSError:(NSString *)description errorCode:(NSInteger)errorCode {
    NSArray *keys = @[NSLocalizedDescriptionKey];
    NSArray *values = @[description];
    NSDictionary *userDict = [NSDictionary dictionaryWithObjects:values forKeys:keys];
    NSError *error = [[NSError alloc] initWithDomain:@"com.markmcguill.strongbox." code:errorCode userInfo:(userDict)];
    
    return error;
}

+ (NSString *)getAppVersion {
    NSDictionary *info = [NSBundle mainBundle].infoDictionary;
    
    return [NSString stringWithFormat:@"%@", info[@"CFBundleShortVersionString"]];
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
//    char baseHostName[256];
//    int success = gethostname(baseHostName, 255);
//
//    if (success != 0) return nil;
//
//    baseHostName[255] = '\0';
//
//    return [NSString stringWithFormat:@"%s.local", baseHostName];
//}

+ (NSString*)getUsername {
    return NSFullUserName();
}

+(NSString *)trim:(NSString*)string {
    return [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

NSComparator finderStringComparator = ^(id obj1, id obj2)
{
    return [Utils finderStringCompare:obj1 string2:obj2];
};

+ (NSComparisonResult)finderStringCompare:(NSString*)string1 string2:(NSString*)string2
{
    // Finder Like String Sort
    // https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/Strings/Articles/SearchingStrings.html#//apple_ref/doc/uid/20000149-SW1
    
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

///////////////////////////////////////////////////////////////////////////////////////////////////

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

+ (NSString *)hexadecimalString:(NSData *)data {
    const unsigned char *dataBuffer = (const unsigned char *)data.bytes;
    
    if (!dataBuffer) {
        return [NSString string];
    }
    
    NSUInteger dataLength = data.length;
    NSMutableString *hexString = [NSMutableString stringWithCapacity:(dataLength * 2)];
    
    for (int i = 0; i < dataLength; ++i) {
        [hexString appendString:[NSString stringWithFormat:@"%02lX", (unsigned long)dataBuffer[i]]];
    }
    
    return [NSString stringWithString:hexString];
}

+ (NSData *)dataFromHexString:(NSString*)string {
    const char *chars = [string UTF8String];
    NSUInteger i = 0, len = string.length;
    
    NSMutableData *data = [NSMutableData dataWithCapacity:len / 2];
    char byteChars[3] = {'\0','\0','\0'};
    unsigned long wholeByte;
    
    while (i < len) {
        byteChars[0] = chars[i++];
        byteChars[1] = chars[i++];
        wholeByte = strtoul(byteChars, NULL, 16);
        [data appendBytes:&wholeByte length:1];
    }
    
    return data;
}

NSData* sha256(NSData *data) {
    uint8_t digest[CC_SHA256_DIGEST_LENGTH] = { 0 };
    
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    
    NSData *out = [NSData dataWithBytes:digest length:CC_SHA256_DIGEST_LENGTH];
    
    return out;
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
UIImage* scaleImage(UIImage* image, CGSize newSize)
{
    float heightToWidthRatio = image.size.height / image.size.width;
    float scaleFactor = 1;
    if(heightToWidthRatio > 0) {
        scaleFactor = newSize.height / image.size.height;
    } else {
        scaleFactor = newSize.width / image.size.width;
    }
    
    CGSize newSize2 = newSize;
    newSize2.width = image.size.width * scaleFactor;
    newSize2.height = image.size.height * scaleFactor;
    
    @autoreleasepool { // Prevent App Extension Crash
        UIGraphicsBeginImageContext(newSize2);
        [image drawInRect:CGRectMake(0,0,newSize2.width,newSize2.height)];
        UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
   
        return newImage;
    }
}
#else
NSImage* scaleImage(NSImage* image, CGSize newSize)
{
    float heightToWidthRatio = image.size.height / image.size.width;
    float scaleFactor = 1;
    if(heightToWidthRatio > 0) {
        scaleFactor = newSize.height / image.size.height;
    } else {
        scaleFactor = newSize.width / image.size.width;
    }
    
    CGSize newSize2 = newSize;
    newSize2.width = image.size.width * scaleFactor;
    newSize2.height = image.size.height * scaleFactor;

    NSImage *ret = [[NSImage alloc] initWithSize:newSize2];
    
    [ret lockFocus];
    
    NSRect thumbnailRect = { 0 };
    //thumbnailRect.origin = thumbnailPoint;
    thumbnailRect.size.width = newSize2.width;
    thumbnailRect.size.height = newSize2.height;
    
    [image drawInRect:thumbnailRect
             fromRect:NSZeroRect
            operation:NSCompositeSourceOver
             fraction:1.0];
    
    [ret unlockFocus];
    
//    CGContextRef contextRef =  CGBitmapContextCreate(0, newSize2.width, newSize2.height, 8, newSize2.width*4, [NSColorSpace genericRGBColorSpace].CGColorSpace, kCGImageAlphaPremultipliedFirst);
//
//    [image drawInRect:CGRectMake(0,0,newSize2.width, newSize2.height)];
//
//    CGImageRef imageRef = CGBitmapContextCreateImage(contextRef);
//    NSImage* ret = [[NSImage alloc] initWithCGImage:imageRef size:NSMakeSize(newSize2.width, newSize2.height)];
//    CFRelease(imageRef);
//    CFRelease(contextRef);
    
    return ret;
    
    //@autoreleasepool { // Prevent App Extension Crash

        //[image drawInRect:CGRectMake(0,0,newSize2.width,newSize2.height)];
        //UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
       // UIGraphicsEndImageContext();
        
        //return newImage;
    //}
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
#endif

//    [[Settings sharedInstance] setPro:NO];
//    [[Settings sharedInstance] setEndFreeTrialDate:nil];
//    [[Settings sharedInstance] setHavePromptedAboutFreeTrial:NO];
//    [[Settings sharedInstance] resetLaunchCount];
//    NSCalendar *cal = [NSCalendar currentCalendar];
//    NSDate *date = [cal dateByAddingUnit:NSCalendarUnitDay value:9 toDate:[NSDate date] options:0];
//    [[Settings sharedInstance] setEndFreeTrialDate:date];


//    [[Settings sharedInstance] setFullVersion:NO];
//[[Settings sharedInstance] setEndFreeTrialDate:nil];
//    NSCalendar *cal = [NSCalendar currentCalendar];
//    NSDate *date = [cal dateByAddingUnit:NSCalendarUnitDay value:-10 toDate:[NSDate date] options:0];
//    [[Settings sharedInstance] setEndFreeTrialDate:date];
//

@end
