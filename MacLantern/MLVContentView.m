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

@interface MLVContentView ()
@property (nonatomic) BOOL draggingInside;
@end

@implementation MLVContentView {
    BOOL _delegateImplementsValidateDrop;
    BOOL _delegateImplementsAcceptDrop;
}

- (void) setDelegate:(id<MLVContentViewDelegate>)delegate {
    if (_delegate != delegate) {
        _delegate = delegate;

        _delegateImplementsValidateDrop = [self.delegate respondsToSelector:@selector(contentView:validateDrop:)];
        _delegateImplementsAcceptDrop = [self.delegate respondsToSelector:@selector(contentView:acceptDrop:)];
    }
}

- (void) setSelected:(BOOL)selected {
    if (_selected != selected) {
        _selected = selected;
        self.needsDisplay = YES;
    }
}

- (void) setDraggingInside:(BOOL)draggingInside {
    if (_draggingInside != draggingInside) {
        _draggingInside = draggingInside;
        self.needsDisplay = YES;
    }
}

#pragma mark -

- (BOOL) acceptsFirstResponder {
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    NSRect b = self.bounds;

    if (self.draggingInside) {
        [[NSColor colorWithCalibratedWhite:0.3 alpha:1.0] set];
    }
    else if (self.selected && [self.window.firstResponder isKindOfClass:[NSView class]] && [self isDescendantOf:(NSView*)self.window.firstResponder]) {
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

#pragma mark -

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)draggingInfo
{
    NSDragOperation dragOperation = NSDragOperationNone;

    if (_delegateImplementsValidateDrop) {
        dragOperation = [self.delegate contentView:self validateDrop:draggingInfo];
    }

    if (dragOperation != NSDragOperationNone) {
        self.draggingInside = YES;
    }
    return dragOperation;
}

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)draggingInfo
{
    NSDragOperation dragOperation = NSDragOperationNone;

    if (_delegateImplementsValidateDrop) {
        dragOperation = [self.delegate contentView:self validateDrop:draggingInfo];
    }

    return dragOperation;
}

- (void)draggingEnded:(id<NSDraggingInfo>)draggingInfo
{
    self.draggingInside = NO;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender
{
    self.draggingInside = NO;
}

- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender
{
    NSDragOperation dragOperation = [self draggingEntered:sender];
    return (dragOperation != NSDragOperationNone);
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
    if (!_delegateImplementsAcceptDrop) {
        return NO;
    }


    BOOL acceptDrop = [self.delegate contentView:self acceptDrop:sender];
    if (acceptDrop) {
        [self.window makeFirstResponder:self.superview];
    }
    return acceptDrop;
}

@end
