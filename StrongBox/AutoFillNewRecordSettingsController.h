//
//  AutoFillNewRecordSettingsController.h
//  Strongbox-iOS
//
//  Created by Mark on 04/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface AutoFillNewRecordSettingsController : UITableViewController

@property (class, readonly) AutoFillNewRecordSettingsController* fromStoryboard;
@property (nonatomic, copy) void (^onDone)(void);

@property (weak, nonatomic) IBOutlet UILabel *labelTitle;
@property (weak, nonatomic) IBOutlet UILabel *labelUsername;
@property (weak, nonatomic) IBOutlet UILabel *labelPassword;
@property (weak, nonatomic) IBOutlet UILabel *labelEmail;
@property (weak, nonatomic) IBOutlet UILabel *labelUrl;
@property (weak, nonatomic) IBOutlet UILabel *labelNotes;

@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentTitle;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentUsername;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentPassword;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentEmail;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentUrl;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentNotes;

@end

NS_ASSUME_NONNULL_END
