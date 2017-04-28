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

#import "MLVMainViewController.h"

@interface MLVMainViewController () <NSSplitViewDelegate>
@property (weak) IBOutlet NSSplitView* splitView;
@property (weak) IBOutlet NSView* presetsHostView;
@property (weak) IBOutlet NSView* patchesHostView;
@property (weak) IBOutlet NSView* infoHostView;
@end

@implementation MLVMainViewController

+ (instancetype) viewController {
    return [[self alloc] initWithNibName:@"MainView" bundle:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

#pragma mark - NSSplitViewDelegate

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)dividerIndex
{
    if (dividerIndex == 0) {
        return 200;
    }

    else if (dividerIndex == 1) {
        return NSWidth(splitView.frame) - 250-1;
    }

    return 0;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)dividerIndex
{
    if (dividerIndex == 0) {
        return NSWidth(splitView.frame) - 250 - 500;
    }

    return NSWidth(splitView.frame) - 250-1;
}

- (void)splitView:(NSSplitView *)splitView resizeSubviewsWithOldSize:(NSSize)oldSize
{
    NSRect splitViewRect = self.splitView.frame;
    if (NSEqualRects(splitViewRect, NSZeroRect)) {
        return;
    }

    NSRect leftRect = self.presetsHostView.frame;

    CGFloat leftWidth = NSWidth(leftRect);
    CGFloat middleWidth = NSWidth(splitViewRect)-250-NSWidth(leftRect)-2;
    if (middleWidth < 500) {
        middleWidth = 500;
        leftWidth = NSWidth(splitViewRect)-250-middleWidth-2;
    }

    self.presetsHostView.frame = NSMakeRect(0, 0, leftWidth, NSHeight(splitViewRect));
    self.patchesHostView.frame = NSMakeRect(leftWidth+1, 0, middleWidth, NSHeight(splitViewRect));
    self.infoHostView.frame = NSMakeRect(NSMaxX(self.patchesHostView.frame)+1, 0, 250, NSHeight(splitViewRect));
}

@end
