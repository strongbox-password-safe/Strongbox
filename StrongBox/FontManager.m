//
//  FontManager.m
//  test-new-ui
//
//  Created by Mark on 18/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "FontManager.h"

@implementation FontManager

+ (FontManager*)shared {
    return FontManager.sharedInstance;
}

+ (instancetype)sharedInstance {
    static FontManager *sharedInstance = nil;

    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FontManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self buildFonts];
        
#if !TARGET_OS_WATCH
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onFontSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
#endif
        
    }
    return self;
}

- (void)buildFonts {
    _regularFont = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    _title1Font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle1];
    _title2Font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle2];
    _title3Font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle3];
    _headlineFont = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    _subheadlineFont = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    _caption1Font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    _caption2Font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2];

    UIFontDescriptor* desc = [self.regularFont.fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitItalic];
    _italicFont = [UIFont fontWithDescriptor:desc size:0];
    
    UIFontDescriptor* desc2 = [self.headlineFont.fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitItalic];
    _headlineItalicFont = [UIFont fontWithDescriptor:desc2 size:0];
    
#if !TARGET_OS_WATCH
    UIFont* customEasyReadFont = [UIFont monospacedSystemFontOfSize:UIFont.labelFontSize weight:UIFontWeightRegular];
    UIFont* customEasyReadBoldFont = [UIFont monospacedSystemFontOfSize:UIFont.labelFontSize weight:UIFontWeightBold];

    _easyReadFont = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:customEasyReadFont];
    _easyReadBoldFont = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:customEasyReadBoldFont];
    _easyReadFontForLargeTextView = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleLargeTitle] scaledFontForFont:customEasyReadFont];
    _easyReadFontForTotp = [UIFont monospacedSystemFontOfSize:30 weight:UIFontWeightBold];
#endif
}

- (void)onFontSizeChanged:(NSNotificationCenter*)center {
    slog(@"Content Size did change notification... rebuilding fonts...");
    [self buildFonts];
}

@end
