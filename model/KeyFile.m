//
//  KeyFile.m
//  MacBox
//
//  Created by Strongbox on 27/03/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

#import "KeyFile.h"
#import "Utils.h"
#import "NSData+Extensions.h"
#import "XMLWriter.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

NSString* const kKeyFileRootElementName = @"KeyFile";
NSString* const kKeyElementName = @"Key";
NSString* const kDataElementName = @"Data";
NSString* const kMetaElementName = @"Meta";
NSString* const kVersionElementName = @"Version";
NSString* const kVersionTwoPointOhText = @"2.0";
NSString* const kHashAttributeName = @"Hash";

static const NSUInteger KeyFileRandomDataLength = 32;

@interface KeyFile ()

@property NSData* data;
@property (readonly) NSString* formattedHexForXml;

@end

@implementation KeyFile

+ (instancetype)newV2 {
    return [[KeyFile alloc] initWithData:getRandomData(KeyFileRandomDataLength)];
}

+ (instancetype)fromHexCodes:(NSString *)codes {
    NSData* data = codes.dataFromHex;
    
    if ( data && data.length == KeyFileRandomDataLength ) {
        return [[KeyFile alloc] initWithData:data];
    }
    
    return nil;
}

- (instancetype)initWithData:(NSData*)data {
    self = [super init];
    if (self) {
        self.data = data;
    }
    return self;
}

- (NSString *)hashString {
    return [self.data.sha256.upperHexString substringToIndex:8];
}

- (NSString *)formattedHex {
    return [self formattedHex:NO];
}

- (NSString *)formattedHexForXml {
    return [self formattedHex:YES];
}

- (NSString*)formattedHex:(BOOL)extraFormattingForXml {
    NSString* randHex = self.data.upperHexString;
    NSMutableString* formattedHex = NSMutableString.string;
    
    for ( int i=0;i<randHex.length;i++ ) {
        unichar chr = [randHex characterAtIndex:i];
        
        if((i & 0x1F) == 0) {
            if ( extraFormattingForXml ) {
                [formattedHex appendString:@"\n"];
                [formattedHex appendString:@"\t\t\t"];
            }
            else if ( i > 0 ) {
                [formattedHex appendString:@"\n"];
            }
        }
        else if((i & 0x07) == 0) {
            [formattedHex appendString:@" "];
        }
        
        [formattedHex appendFormat:@"%c", chr];
    }
    
    if ( extraFormattingForXml ) {
        [formattedHex appendString:@"\n\t\t"];
    }
    
    return formattedHex;
}

- (NSString *)xml {
    XMLWriter* xmlWriter = [[XMLWriter alloc] init];
    
    [xmlWriter setPrettyPrinting:@"\t" withLineBreak:@"\n"];
    
    [xmlWriter setAutomaticEmptyElements:YES];
    
    [xmlWriter writeStartDocumentWithEncodingAndVersion:@"UTF-8" version:@"1.0"];
    
    [xmlWriter writeStartElement:kKeyFileRootElementName];
    [xmlWriter writeStartElement:kMetaElementName];
    [xmlWriter writeStartElement:kVersionElementName];
    [xmlWriter writeCharacters:kVersionTwoPointOhText];
    [xmlWriter writeEndElement];
    [xmlWriter writeEndElement];
    
    [xmlWriter writeStartElement:kKeyElementName];
    [xmlWriter writeStartElement:kDataElementName];
    [xmlWriter writeAttribute:kHashAttributeName value:self.hashString];
    
    [xmlWriter writeCharacters:self.formattedHexForXml];
    [xmlWriter writeEndElement];
    [xmlWriter writeEndElement];
    [xmlWriter writeEndElement];
    
    [xmlWriter writeEndDocument];
    
    return xmlWriter.toString;
}


#ifndef IS_APP_EXTENSION

- (NSString*)getHtml {
    NSError* error;
    
    NSString* fmt = self.formattedHex;
    NSArray<NSString*>* lines = [fmt componentsSeparatedByString:@"\n"];
    
    NSString* markdown = [NSString stringWithFormat:@"# Key File Recovery\n---\n## Hash: ```%@``` \n---\n## Data (Hex Codes):\n## ```%@``` \n## ```%@``` \n---\nPrinted: %@", self.hashString, lines[0], lines[1], NSDate.now.iso8601DateString];
    
    NSString* html = [StrongboxCMarkGFMHelper convertToHtmlFragmentWithMarkdown:markdown error:&error];
    
    return html;
}

#if TARGET_OS_IPHONE

- (void)printRecoverySheet:(UIViewController*)viewController {
    NSString* html = [self getHtml];
    if ( !html ) {
        [Alerts error:viewController error:[Utils createNSError:@"Could not generate HTML" errorCode:123]];
        return;
    }
        
    UIMarkupTextPrintFormatter *formatter = [[UIMarkupTextPrintFormatter alloc] initWithMarkupText:html];
    
    UIPrintInteractionController.sharedPrintController.printFormatter = formatter;
    
    [UIPrintInteractionController.sharedPrintController presentAnimated:YES completionHandler:nil];
}
#else
- (void)printRecoverySheet {
    NSString* html = [self getHtml];
    if ( !html ) {
        [MacAlerts error:[Utils createNSError:@"Could not generate HTML" errorCode:123] window:DBManagerPanel.sharedInstance.contentViewController.view.window];
        return;
    }
    
    WebView *webView = [[WebView alloc] init];
    
    [webView.mainFrame loadHTMLString:html baseURL:nil];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSPrintInfo* pi = NSPrintInfo.sharedPrintInfo;
        
        
        NSPrintOperation* printOp = [NSPrintOperation printOperationWithView:webView.mainFrame.frameView.documentView
                                                                   printInfo:pi];
        
        [printOp runOperation];
    });
}

#endif
#endif

@end
