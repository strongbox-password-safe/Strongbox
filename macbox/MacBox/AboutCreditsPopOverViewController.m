//
//  AboutCreditsPopOverViewController.m
//  MacBox
//
//  Created by Strongbox on 13/02/2025.
//  Copyright © 2025 Mark McGuill. All rights reserved.
//

#import "AboutCreditsPopOverViewController.h"

@interface AboutCreditsPopOverViewController ()

@property (unsafe_unretained) IBOutlet NSTextView *textView;

@end

@implementation AboutCreditsPopOverViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSURL* rtfPath = [NSBundle.mainBundle URLForResource:@"About" withExtension:@"rtf"];
    
    if(rtfPath) {
        NSError* error;
        NSMutableAttributedString* attributedStringWithRtf = [[NSMutableAttributedString alloc] initWithURL:rtfPath
                                                                                                    options:@{ NSDocumentTypeDocumentOption :  NSRTFTextDocumentType }
                                                                                         documentAttributes:nil
                                                                                                      error:&error];
        NSColor *color = NSColor.labelColor;
        NSDictionary *attrs = @{ NSForegroundColorAttributeName : color };

        [attributedStringWithRtf addAttributes:attrs range:NSMakeRange(0, attributedStringWithRtf.length)];

        NSAttributedString* attributedString = error ? [[NSAttributedString alloc] initWithString:error.description] : attributedStringWithRtf;

        [self.textView.textStorage setAttributedString:attributedString];
    }
}

@end
