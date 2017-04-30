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

#import "MLVBatchViewController.h"
#import "MLVBatch.h"
#import "MLVJob.h"
#import "MLVJobViewController.h"
#import "NSObject+MacLantern.h"
#import "NSColor+MacLantern.h"
#import "NSImage+MacLantern.h"
#import "MLVTypes.h"
#import "MLVMainWindowController.h"
#import "MLVContentView.h"

@interface MLVBatchViewController ()
@property (weak) IBOutlet NSView* containerView;
@property (weak) IBOutlet NSArrayController* arrayController;
@property (strong) IBOutlet NSView* placeholderView;

@property (nonatomic, strong) NSArray<MLVJobViewController*>* jobsViewControllers;
@property (nonatomic, strong) NSArray<NSLayoutConstraint*>* jobViewContraints;

@property (nonatomic, strong) NSArray<NSLayoutConstraint*>* placeholderViewConstraints;
@property (readonly) NSImage* iconImage;
@end

@implementation MLVBatchViewController

+ (instancetype) viewController {
    return [[self alloc] initWithNibName:@"BatchView" bundle:nil];
}

- (void) dealloc {
    [self.arrayController removeTaskObserver:self forKeyPath:@"arrangedObjects"];
    [self.arrayController removeTaskObserver:self forKeyPath:@"arrangedObjects.name"];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self _updateJobsViewControllers];
    WEAK_SELF
    [self.arrayController addTaskObserver:self forKeyPath:@"arrangedObjects" task:^(id obj, NSDictionary *change) {
        STRONG_SELF
        [self _updateJobsViewControllers];
    }];

    [self.arrayController addTaskObserver:self forKeyPath:@"arrangedObjects.name" task:^(id obj, NSDictionary *change) {
        STRONG_SELF
        [self.batch willChangeValueForKey:@"name"];
        [self.batch didChangeValueForKey:@"name"];
    }];

    [self _updateSelection];
}

- (void) viewDidAppear {
    [super viewDidAppear];

    WEAK_SELF
    [self.view.window.windowController addTaskObserver:self forKeyPath:@"selectedObjects" task:^(id obj, NSDictionary *change) {
        STRONG_SELF
        [self _updateSelection];
    }];
}

- (void) viewWillDisappear {
    [super viewWillDisappear];
    [self.view.window.windowController removeTaskObserver:self forKeyPath:@"selectedObjects"];
}

#pragma mark -

+ (NSSet*) keyPathsForValuesAffectingIconImage {
    return [NSSet setWithObject:@"view.selected"];
}

- (NSImage*) iconImage {
    NSColor* iconColor = (((MLVContentView*)self.view).selected) ? [NSColor whiteColor] : [NSColor mlv_controlColor];
    return [[NSImage imageNamed:@"iconFolder"] imageWithColor:iconColor];
}

- (void) _updateSelection {
    NSArray* selectedObjects = ((MLVMainWindowController*)self.view.window.windowController).selectedObjects;
    for(MLVJobViewController* viewController in self.jobsViewControllers) {
        ((MLVContentView*)viewController.view).selected = [selectedObjects containsObject:viewController.job];
    }
}

- (void) _updateJobsViewControllers {
    if (self.batch.jobs.count > 0) {
        NSMutableArray<MLVJobViewController*>* jobsViewControllers = [[NSMutableArray alloc] init];
        for(MLVJob* job in self.batch.jobs) {
            MLVJobViewController* jobViewController = [MLVJobViewController viewController];
            jobViewController.job = job;
            [jobsViewControllers addObject:jobViewController];
        }
        self.jobsViewControllers = jobsViewControllers;
        [self showPlaceholderView:NO];
    }
    else {
        self.jobsViewControllers = nil;
        [self showPlaceholderView:YES];
    }
}

- (void) showPlaceholderView:(BOOL)show
{
    if (show) {
        [self.containerView addSubview:self.placeholderView];

        NSMutableArray* placeholderViewConstraints = [[NSMutableArray alloc] init];

        [placeholderViewConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[placeholderView]|"
                                                                                       options:0
                                                                                       metrics:nil
                                                                                         views:@{@"placeholderView" : self.placeholderView}]];

        [placeholderViewConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[placeholderView]|"
                                                                                                options:0
                                                                                                metrics:nil
                                                                                                  views:@{@"placeholderView" : self.placeholderView}]];

        [self.containerView addConstraints:placeholderViewConstraints];
        self.placeholderViewConstraints = placeholderViewConstraints;
    }
    else {
        if (self.placeholderViewConstraints) {
            [self.containerView removeConstraints:self.placeholderViewConstraints];
            self.placeholderViewConstraints = nil;
        }
        [self.placeholderView removeFromSuperview];
    }
}

- (void) setJobsViewControllers:(NSArray<MLVJobViewController *> *)jobsViewControllers
{
    if (_jobsViewControllers != jobsViewControllers)
    {
        if (_jobsViewControllers) {
            if (self.jobViewContraints) {
                [self.containerView removeConstraints:self.jobViewContraints];
                self.jobViewContraints = nil;
            }

            for(NSViewController* viewController in _jobsViewControllers) {
                [viewController.view removeFromSuperview];
                [viewController removeFromParentViewController];
            }
        }

        _jobsViewControllers = jobsViewControllers;

        if (jobsViewControllers.count > 0)
        {
            NSMutableArray* jobViewContraints = [[NSMutableArray alloc] init];

            NSViewController* lastViewController = nil;
            for(NSViewController* viewController in _jobsViewControllers)
            {
                [self addChildViewController:viewController];
                [self.containerView addSubview:viewController.view];

                [jobViewContraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[contentView]|"
                                                                                                 options:0
                                                                                                 metrics:nil
                                                                                                   views:@{@"contentView" : viewController.view}]];

                if (!lastViewController) {
                    [jobViewContraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[contentView]"
                                                                                                     options:0
                                                                                                     metrics:nil
                                                                                                       views:@{@"contentView" : viewController.view}]];
                }
                else {
                    [jobViewContraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[lastView]-(2)-[contentView]"
                                                                                                     options:0
                                                                                                     metrics:nil
                                                                                                       views:@{@"contentView" : viewController.view, @"lastView" : lastViewController.view}]];
                }
                lastViewController = viewController;
            }

            [jobViewContraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[lastView]|"
                                                                                             options:0
                                                                                             metrics:nil
                                                                                               views:@{@"lastView" : lastViewController.view}]];


            [self.containerView addConstraints:jobViewContraints];
            self.jobViewContraints = jobViewContraints;
        }
    }
}

- (void) mouseDown:(NSEvent *)event {
    [self.view.window makeFirstResponder:self.view];
    [super mouseDown:event];
}


- (void) mouseUp:(NSEvent *)event
{
    NSMutableArray<MLVJob*>* selectedJobs = [[NSMutableArray alloc] init];

    NSPoint location = [self.view convertPoint:event.locationInWindow fromView:nil];
    for(MLVJobViewController* viewController in _jobsViewControllers) {
        NSRect viewRect = [self.view convertRect:viewController.view.bounds fromView:viewController.view];
        if (NSPointInRect(location, viewRect)) {
            [selectedJobs addObject:viewController.job];
        }
    }

    if (selectedJobs.count > 0) {
        ((MLVMainWindowController*)self.view.window.windowController).selectedObjects = selectedJobs;
    }
    else {
        [super mouseUp:event];
    }
}

- (IBAction) addFile:(id)sender
{
    NSOpenPanel* openPanel = [[NSOpenPanel alloc] init];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setCanChooseFiles:YES];
    [openPanel setAllowsMultipleSelection:YES];
    [openPanel setAllowedFileTypes:@[ @"mlv" ]];
    openPanel.title = @"Add file or folder";

    [openPanel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger returnCode) {
        if (returnCode == NSFileHandlingPanelOKButton) {
            NSArray* urls = [openPanel URLs];
            for(NSURL* url in urls) {
                [self.batch addJobWithURL:url];
            }
        }
    }];
}
@end
