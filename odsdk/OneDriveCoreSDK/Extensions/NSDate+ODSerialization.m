//  Copyright 2015 Microsoft Corporation
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "NSDate+ODSerialization.h"

@implementation NSDate (Serialization)

static NSString *dateFormatWithMillis = @"yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ";
static NSString *dateFormatWithoutMillis = @"yyyy-MM-dd'T'HH:mm:ssZ";

- (NSString *)od_toString
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:dateFormatWithMillis];
    NSLocale *posix = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    [dateFormatter setLocale:posix];
    return [dateFormatter stringFromDate:self];
}

+ (instancetype)od_dateFromString:(NSString *)dateString
{
    NSDate *date = nil;
    if (dateString){
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:dateFormatWithMillis];
        NSLocale *posix = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        [dateFormatter setLocale:posix];
        date = [dateFormatter dateFromString:dateString];
        // If we couldn't parse the date, it may have no milliseconds on the string.
        if (!date){
            [dateFormatter setDateFormat:dateFormatWithoutMillis];
            date = [dateFormatter dateFromString:dateString];
        }
    }
    return date;   
}

@end
