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

#import "MLVContentView.h"
#import "NSColor+MacLantern.h"

@implementation MLVContentView

- (BOOL) acceptsFirstResponder {
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    NSRect b = self.bounds;

    if (self.selected && [self.window.firstResponder isKindOfClass:[NSView class]] && [self isDescendantOf:(NSView*)self.window.firstResponder]) {
        [[NSColor mlv_selectionColor] set];
    }
    else if (self.selected && [self.window.firstResponder isKindOfClass:[NSView class]] && ![self isDescendantOf:(NSView*)self.window.firstResponder]) {
        [[NSColor mlv_unfocusSelectionColor] set];
    }
    else {
        [[NSColor colorWithCalibratedWhite:0.15 alpha:1.0] set];
    }

    [[NSBezierPath bezierPathWithRoundedRect:b xRadius:5 yRadius:5] fill];

    [[NSColor mlv_windowColor] set];
    NSRect insetInsetRect = NSMakeRect(NSMinX(b)+2, NSMinY(b)+2, NSWidth(b)-4, NSHeight(b)-2-30);
    [[NSBezierPath bezierPathWithRoundedRect:insetInsetRect xRadius:4 yRadius:4] fill];
}

- (void) setSelected:(BOOL)selected {
    if (_selected != selected) {
        _selected = selected;
        self.needsDisplay = YES;
    }
}

@end
