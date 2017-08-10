//
//  Document.m
//  MacBox
//
//  Created by Mark on 01/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "Document.h"
#import "ViewController.h"
#import "ViewModel.h"

@interface Document ()

@property (strong, nonatomic) ViewModel* model;
@property NSWindowController* windowController;

@end

@implementation Document

- (instancetype)init {
    self = [super init];
    
    if (self) {
        // Add your subclass-specific initialization here.
    }
    
    return self;
}

+ (BOOL)autosavesInPlace {
    return YES;
}


- (void)makeWindowControllers {
    // Override to return the Storyboard file name of the document.
    
    self.windowController = [[NSStoryboard storyboardWithName:@"Main" bundle:nil] instantiateControllerWithIdentifier:@"Document Window Controller"];
    
    [self addWindowController:self.windowController];

    [self setWindowModel:self.model];
}


- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    // Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning nil.
    
    // You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
    
    // [NSException raise:@"UnimplementedMethod" format:@"%@ is unimplemented", NSStringFromSelector(_cmd)];
    
    return nil;
}


- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
    self.model = [[ViewModel alloc] initWithData:data];
    
    [self setWindowModel:self.model];
    
    return YES;
}


- (void)setWindowModel:(ViewModel*)model {
    ViewController *vc = (ViewController*)self.windowController.contentViewController;
    
    [vc setModel:self.model];
}

- (void)info: (NSString *)info {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:info];
    
    [alert addButtonWithTitle:@"Ok"];
    
    [alert runModal];
}

- (NSString *)input: (NSString *)prompt defaultValue: (NSString *)placeHolder {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:prompt];
    
    [alert addButtonWithTitle:@"Ok"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    [input setStringValue:placeHolder];
    
    [alert setAccessoryView:input];
    NSInteger button = [alert runModal];
    
    if (button == NSAlertFirstButtonReturn) {
        return [input stringValue];
    } else if (button == NSAlertSecondButtonReturn) {
        return nil;
    }
    
    return nil;
}

@end
