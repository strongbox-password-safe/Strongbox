//
//  FontManager.m
//  test-new-ui
//
//  Created by Mark on 18/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "FontManager.h"
#import "Settings.h"

static NSString* const kEasyReadFontName = @"Menlo";
static NSString* const kEasyReadBoldFontName = @"Menlo-Bold";

@implementation FontManager

+ (instancetype)sharedInstance {
    static FontManager *sharedInstance = nil;

    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FontManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self buildFonts];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onFontSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
    }
    return self;
}

- (void)buildFonts {
    _regularFont = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    _title2Font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle2];
    _title3Font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle3];
    _caption1Font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    _caption2Font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2];

    UIFontDescriptor* desc = [self.regularFont.fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitItalic];
    _italicFont = [UIFont fontWithDescriptor:desc size:0];

    _easyReadFontForTotp = [UIFont fontWithName:kEasyReadFontName size:30.0];

    UIFont* customFont = [UIFont fontWithName:kEasyReadFontName size:UIFont.labelFontSize];
    UIFont* customBoldFont = [UIFont fontWithName:kEasyReadBoldFontName size:UIFont.labelFontSize];
    

    
    
    if (@available(iOS 11.0, *)) {
        _easyReadFont = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:customFont];
        _easyReadBoldFont = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:customBoldFont];

        _easyReadFontForLargeTextView = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleLargeTitle] scaledFontForFont:customFont];

    } else {
        _easyReadFont = customFont;
        _easyReadBoldFont = customBoldFont;
        _easyReadFontForLargeTextView = _easyReadFontForTotp;
    }
    
    NSLog(@"Fonts built: [%@-%@-%@]", self.regularFont, self.easyReadFont, self.easyReadFontForTotp);
}

- (void)onFontSizeChanged:(NSNotificationCenter*)center {
    NSLog(@"Content Size did change notification... rebuilding fonts...");
    [self buildFonts];
}

@end
