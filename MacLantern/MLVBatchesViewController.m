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

#import "MLVBatchesViewController.h"
#import "MLVBatchViewController.h"
#import "MLVBatch.h"
#import "MLVDataManager.h"
#import "NSColor+MacLantern.h"
#import "NSObject+MacLantern.h"
#import "MLVTypes.h"
#import "MLVMainWindowController.h"
#import "MLVContentView.h"

@interface MLVBatchesViewController ()
@property (weak) IBOutlet NSView* containerView;
@property (weak) IBOutlet NSScrollView* scrollView;
@property (weak) IBOutlet NSArrayController* arrayController;

@property (nonatomic, strong) NSArray<MLVBatchViewController*>* batchViewControllers;
@property (nonatomic, strong) NSArray<NSLayoutConstraint*>* batchViewContraints;
@property (nonatomic, strong) NSArray<MLVBatch*>* selectedBatches;
@end

@implementation MLVBatchesViewController

+ (instancetype) viewController {
    return [[self alloc] initWithNibName:@"BatchesView" bundle:nil];
}

- (void) dealloc {
    [self.arrayController removeTaskObserver:self forKeyPath:@"arrangedObjects"];
    [self unbind:@"batches"];
}


- (void)viewDidLoad {
    [super viewDidLoad];

    self.scrollView.backgroundColor = [NSColor mlv_panelColor];
    self.scrollView.drawsBackground = YES;

    self.title = @"Batches";
    [self bind:@"batches" toObject:[MLVDataManager sharedManager]  withKeyPath:@"batches" options:nil];

    [self _updateBatchViewController];
    WEAK_SELF
    [self.arrayController addTaskObserver:self forKeyPath:@"arrangedObjects" task:^(id obj, NSDictionary *change) {
        STRONG_SELF
        [self _updateBatchViewController];
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

- (void) _updateSelection {
    NSArray* selectedObjects = ((MLVMainWindowController*)self.view.window.windowController).selectedObjects;
    for(MLVBatchViewController* viewController in self.batchViewControllers) {
        ((MLVContentView*)viewController.view).selected = [selectedObjects containsObject:viewController.batch];
    }
}

- (void) _updateBatchViewController {
    if (self.batches) {
        NSMutableArray<MLVBatchViewController*>* batchViewControllers = [[NSMutableArray alloc] init];
        for(MLVBatch* batch in self.batches) {
            MLVBatchViewController* batchViewController = [MLVBatchViewController viewController];
            batchViewController.batch = batch;
            [batchViewControllers addObject:batchViewController];
        }
        self.batchViewControllers = batchViewControllers;
    }
    else {
        self.batchViewControllers = nil;
    }
}

- (void) setBatchViewControllers:(NSArray<MLVBatchViewController *> *)batchViewControllers
{
    if (_batchViewControllers != batchViewControllers)
    {
        if (_batchViewControllers) {
            if (self.batchViewContraints) {
                [self.containerView removeConstraints:self.batchViewContraints];
                self.batchViewContraints = nil;
            }

            for(NSViewController* viewController in _batchViewControllers) {
                [viewController.view removeFromSuperview];
                [viewController removeFromParentViewController];
            }
        }

        _batchViewControllers = batchViewControllers;

        if (batchViewControllers.count > 0)
        {
            NSMutableArray* batchViewContraints = [[NSMutableArray alloc] init];

            NSViewController* lastViewController = nil;
            for(NSViewController* viewController in _batchViewControllers)
            {
                [self addChildViewController:viewController];
                [self.containerView addSubview:viewController.view];

                [batchViewContraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[contentView]|"
                                                                                                    options:0
                                                                                                    metrics:nil
                                                                                                      views:@{@"contentView" : viewController.view}]];

                if (!lastViewController) {
                    [batchViewContraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[contentView]"
                                                                                                        options:0
                                                                                                        metrics:nil
                                                                                                          views:@{@"contentView" : viewController.view}]];
                }
                else {
                    [batchViewContraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[lastView]-(2)-[contentView]"
                                                                                                        options:0
                                                                                                        metrics:nil
                                                                                                          views:@{@"contentView" : viewController.view, @"lastView" : lastViewController.view}]];
                }
                lastViewController = viewController;
            }

            [batchViewContraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[lastView]|"
                                                                                                options:0
                                                                                                metrics:nil
                                                                                                  views:@{@"lastView" : lastViewController.view}]];

            [self.containerView addConstraints:batchViewContraints];
            self.batchViewContraints = batchViewContraints;
        }
    }
}

- (void) mouseDown:(NSEvent *)event {
    [self.view.window makeFirstResponder:self.view];
}


- (void) mouseUp:(NSEvent *)event
{
    NSMutableArray<MLVBatch*>* selectedBatches = [[NSMutableArray alloc] init];

    NSPoint location = [self.view convertPoint:event.locationInWindow fromView:nil];
    for(MLVBatchViewController* viewController in _batchViewControllers) {
        NSRect viewRect = [self.view convertRect:viewController.view.bounds fromView:viewController.view];
        if (NSPointInRect(location, viewRect)) {
            [selectedBatches addObject:viewController.batch];
        }
    }

    ((MLVMainWindowController*)self.view.window.windowController).selectedObjects = selectedBatches;
}

@end
