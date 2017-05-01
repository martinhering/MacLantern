/*
 * Copyright (C) 2017 Martin Hering
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the
 * Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor,
 * Boston, MA  02110-1301, USA.
 */

#import "MLVJobViewController.h"
#import "MLVContentView.h"
#import "NSImage+MacLantern.h"
#import "NSColor+MacLantern.h"
#import "NSObject+MacLantern.h"
#import "MLVJob.h"
#import "MLVTypes.h"

@interface MLVJobViewController ()
@property (weak) IBOutlet NSView* containerView;
@property (weak) IBOutlet NSProgressIndicator* readingFileProgressIndicator;
@property (strong) IBOutlet NSView* readingFileView;

@property (readonly) NSImage* iconImage;
@property (nonatomic, strong) NSArray<NSLayoutConstraint*>* readingFileViewConstraints;
@end

@implementation MLVJobViewController

+ (instancetype) viewController {
    return [[self alloc] initWithNibName:@"JobView" bundle:nil];
}

- (void) dealloc
{
    self.job = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.readingFileProgressIndicator.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];

    [self showReadingFileView:self.job.readingFile];
}

- (void) setJob:(MLVJob *)job {
    if (_job != job) {
        if (_job) {
            [_job removeTaskObserver:self forKeyPath:@"readingFile"];
        }

        _job = job;
        if ([self isViewLoaded]) {
            [self showReadingFileView:job.readingFile];
        }

        if (job) {
            WEAK_SELF
            [self.job addTaskObserver:self forKeyPath:@"readingFile" task:^(id obj, NSDictionary *change) {
                STRONG_SELF
                [self showReadingFileView:self.job.readingFile];
            }];
        }
    }
}

#pragma mark -

+ (NSSet*) keyPathsForValuesAffectingIconImage {
    return [NSSet setWithObject:@"view.selected"];
}

- (NSImage*) iconImage {
    NSColor* iconColor = (((MLVContentView*)self.view).selected) ? [NSColor whiteColor] : [NSColor mlv_controlColor];
    return [[NSImage imageNamed:@"iconFile"] imageWithColor:iconColor];
}

- (void) showReadingFileView:(BOOL)show
{
    if (show) {
        [self.containerView addSubview:self.readingFileView];

        NSMutableArray* readingFileViewConstraints = [[NSMutableArray alloc] init];

        [readingFileViewConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[readingFileView]|"
                                                                                                options:0
                                                                                                metrics:nil
                                                                                                  views:@{@"readingFileView" : self.readingFileView}]];

        [readingFileViewConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[readingFileView]|"
                                                                                                options:0
                                                                                                metrics:nil
                                                                                                  views:@{@"readingFileView" : self.readingFileView}]];

        [self.containerView addConstraints:readingFileViewConstraints];
        self.readingFileViewConstraints = readingFileViewConstraints;

        [self.readingFileProgressIndicator startAnimation:nil];
    }
    else {
        if (self.readingFileViewConstraints) {
            [self.containerView removeConstraints:self.readingFileViewConstraints];
            self.readingFileViewConstraints = nil;
        }
        [self.readingFileView removeFromSuperview];

        [self.readingFileProgressIndicator stopAnimation:nil];
    }
}

@end
