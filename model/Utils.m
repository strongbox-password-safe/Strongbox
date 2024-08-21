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
#import "NSArray+Extensions.h"

#include <pwd.h>

#import <CoreImage/CoreImage.h>

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

+ (NSArray<NSString*>*)getTagsFromTagString:(NSString*)string {
    NSArray<NSString*>* tags = [string componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@";:,"]]; 
    
    NSArray<NSString*>* trimmed = [tags map:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
        return [Utils trim:obj];
    }];
    
    NSArray<NSString*>* filtered = [trimmed filter:^BOOL(NSString * _Nonnull obj) {
        return obj.length > 0;
    }];

    return filtered;
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

+ (NSString *)likelyFileExtensionForData:(NSData *)data {
    uint8_t c;
    [data getBytes:&c length:1];
    
    switch (c) {
        case 0xFF:
            
            return @"jpeg";
            break;
        case 0x89:
            
            return @"png";
            break;
        case 0x47:
            
            return @"gif";
            break;
        case 0x49:
        case 0x4D:
            
            return @"tiff";
            break;
        case 0x25:
            
            return @"pdf";
            break;
            
            
            
            
        case 0x46:
            
            return @"txt";
            break;
        default:
            return @"txt";
    }
    return nil;
}

#if TARGET_OS_IPHONE && !IS_APP_EXTENSION
+ (void)openStrongboxSettingsAndPermissionsScreen {
    NSString* settings = [NSString stringWithFormat:@"%@&path=LOCATION/%@", UIApplicationOpenSettingsURLString, NSBundle.mainBundle.bundleIdentifier];
    NSURL* url = [NSURL URLWithString:settings];
    [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
}
#endif

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
    
    return [NSData dataWithBytes:uid length:sizeof(uuid_t)].upperHexString;
}

NSUUID* uuidFromKeePassStringId(NSString* foo) {
    if ( foo.length == 0 ) {
        return nil;
    }
    
    
    
    NSString* stringId = [[foo.trimmed stringByReplacingOccurrencesOfString:@"-" withString:@""] stringByReplacingOccurrencesOfString:@" " withString:@""];
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

#if TARGET_OS_IPHONE
+ (BOOL)isiPadPro {
    

    return (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) && MAX(UIScreen.mainScreen.bounds.size.width, UIScreen.mainScreen.bounds.size.height) > 1024;
}

+ (BOOL)isiPad {
    return (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad);
}

#endif

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
        slog(@"n > 8 passed to littleEndianNBytesToInt64");
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

uint32_t getRandomUint32(void) {
    uint32_t ret;
    if(SecRandomCopyBytes(kSecRandomDefault, sizeof(uint32_t), &ret))
    {
        slog(@"Could not securely copy new random bytes");
        return -1;
    }
    
    return ret;
}

NSData* getRandomData(uint32_t length) {
    NSMutableData *start = [NSMutableData dataWithLength:length];
    if(SecRandomCopyBytes(kSecRandomDefault, length, start.mutableBytes))
    {
        slog(@"Could not securely copy new random bytes");
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

+ (UIImage *)makeRoundedImage:(UIImage*)image radius:(float)radius {
    CALayer *imageLayer = [CALayer layer];
    imageLayer.frame = CGRectMake(0, 0, image.size.width, image.size.height);
    imageLayer.contents = (id) image.CGImage;

    imageLayer.masksToBounds = YES;
    imageLayer.cornerRadius = radius;

    UIGraphicsBeginImageContext(image.size);
    [imageLayer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *roundedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return roundedImage;
}

#else

NSColor* NSColorFromRGB(NSUInteger rgbValue) {
    return [NSColor colorWithCalibratedRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0];
}

+ (NSImage *)imageTintedWithColor:(NSImage*)img tint:(NSColor *)tint {
    NSImage *image = [img copy];
    if (tint) {
        [image lockFocus];
        [tint set];
        NSRect imageRect = {NSZeroPoint, [image size]};
        NSRectFillUsingOperation(imageRect, NSCompositingOperationSourceAtop);
        [image unlockFocus];
    }
    return image;
}

NSImage* scaleImage(NSImage* image, CGSize newSize) {
    @try {
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

        @autoreleasepool { 
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
    } @catch (NSException *exception) {
        slog(@"Exception in scaleImage: [%@]", exception);
        return image;
    } @finally { }
}

+ (void)dismissViewControllerCorrectly:(NSViewController*)vc {
    if ( !vc ) {
        slog(@"🔴 nil viewController passed to dismissViewControllerCorrectly");
        return;
    }
    
    if ( vc.presentingViewController ) {
        [vc.presentingViewController dismissViewController:vc];
    }
    else if ( vc.view.window.sheetParent ) {
        [vc.view.window.sheetParent endSheet:vc.view.window returnCode:NSModalResponseCancel];
    }
    else {
        [vc.view.window close];
    }
}

#endif

#if TARGET_OS_IPHONE
+ (NSData*)getImageDataFromPickedImage:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info error:(NSError**)error {
    NSString* mediaType = [info objectForKey:UIImagePickerControllerMediaType];
    BOOL isImage = UTTypeConformsTo((__bridge CFStringRef)mediaType, kUTTypeImage) != 0;
    
    NSURL *url;
    NSData* data;
    
    if ( isImage ) {
        url =  [info objectForKey:UIImagePickerControllerImageURL];
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
    CIImage* qrCode = [self getQrCodeCIImage:string pointSize:pointSize];

    return [UIImage imageWithCIImage:qrCode
                               scale:[UIScreen mainScreen].scale
                         orientation:UIImageOrientationUp];
}

#else

+ (NSImage*)getQrCode:(NSString*)string pointSize:(NSUInteger)pointSize {
    CIImage* qrCode = [self getQrCodeCIImage:string pointSize:pointSize];

    NSCIImageRep *rep = [NSCIImageRep imageRepWithCIImage:qrCode];
    NSImage *nsImage = [[NSImage alloc] initWithSize:rep.size];

    [nsImage addRepresentation:rep];

    return nsImage;
}

#endif

+ (CIImage *)getQrCodeCIImage:(NSString *)qrString pointSize:(NSUInteger)pointSize {
    CIImage *input = [self createQRForString:qrString];

    
#if TARGET_OS_IPHONE
    NSUInteger kImageViewSize = pointSize * UIScreen.mainScreen.scale;
#else
    NSUInteger kImageViewSize = pointSize * 2;
#endif
    
    CGFloat scale = kImageViewSize / input.extent.size.width;

    CGAffineTransform transform = CGAffineTransformMakeScale(scale, scale);
    CIImage *qrCode = [input imageByApplyingTransform:transform];
    
    return qrCode;
}

+ (CIImage *)createQRForString:(NSString *)qrString {
    NSData *stringData = [qrString dataUsingEncoding:NSISOLatin1StringEncoding];

    CIFilter *qrFilter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    
    
    
    [qrFilter setValue:stringData forKey:@"inputMessage"];
    [qrFilter setValue:@"H" forKey:@"inputCorrectionLevel"];
    
    return qrFilter.outputImage;
}

NSString* localizedYesOrNoFromBool(BOOL george) {
    return george ?
    NSLocalizedString(@"alerts_yes", @"Yes") :
    NSLocalizedString(@"alerts_no", @"No");
}

NSString* localizedOnOrOffFromBool(BOOL george) {
    return george ?
    NSLocalizedString(@"generic_state_on", @"On") :
    NSLocalizedString(@"generic_state_off", @"Off");
}

#if TARGET_OS_IPHONE

#ifndef IS_APP_EXTENSION
+ (BOOL)isAppInForeground {
    UIApplicationState state = UIApplication.sharedApplication.applicationState;
    return state == UIApplicationStateActive;

}
#endif

#else
BOOL checkForScreenRecordingPermissionsOnMac(void) {
    
    BOOL canRecordScreen = NO;
    NSRunningApplication *runningApplication = NSRunningApplication.currentApplication;
    NSNumber *ourProcessIdentifier = [NSNumber numberWithInteger:runningApplication.processIdentifier];
    
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
    NSUInteger numberOfWindows = CFArrayGetCount(windowList);
    
    for (int index = 0; index < numberOfWindows; index++) {
        
        NSDictionary *windowInfo = (NSDictionary *)CFArrayGetValueAtIndex(windowList, index);
        NSString *windowName = windowInfo[(id)kCGWindowName];
        NSNumber *processIdentifier = windowInfo[(id)kCGWindowOwnerPID];
        
        
        if (! [processIdentifier isEqual:ourProcessIdentifier]) {
            
            pid_t pid = processIdentifier.intValue;
            NSRunningApplication *windowRunningApplication = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
            
            if (! windowRunningApplication) {
                
            }
            else {
                NSString *windowExecutableName = windowRunningApplication.executableURL.lastPathComponent;
                
                if (windowName) {
                    if ([windowExecutableName isEqual:@"Dock"]) {
                        
                    }
                    else {
                        canRecordScreen = YES;
                        break;
                    }
                }
            }
        }
    }

    CFRelease(windowList);
    
    return canRecordScreen;
}

#endif

















    
































+ (NSURL*)userHomeDirectoryEvenInSandbox {
    const char *home = getpwuid(getuid())->pw_dir;
    
    NSString *path = [[NSFileManager defaultManager]
                      stringWithFileSystemRepresentation:home
                      length:strlen(home)];

    NSURL *url = [NSURL fileURLWithPath:path isDirectory:YES];
    
    return url;
}

@end
