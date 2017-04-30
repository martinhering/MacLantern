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

#import "MLVButtonCell.h"
#import "NSImage+MacLantern.h"
#import "NSColor+MacLantern.h"

@implementation MLVButtonCell

- (NSColor*) color {
    NSColor* normalColor = [NSColor mlv_controlColor];
    NSColor* highlightColor = [NSColor whiteColor];

    NSCellStyleMask showsStateBy = self.showsStateBy;
    return (self.highlighted || (showsStateBy != NSNoCellMask && self.state == NSOnState)) ? highlightColor : normalColor;
}

- (void) drawBezelWithFrame:(NSRect)frame inView:(NSView *)controlView
{

}

- (void) drawImage:(NSImage *)image withFrame:(NSRect)frame inView:(NSButton *)controlView
{
    image = [image imageWithColor:[self color]];

    [image drawInRect:frame
             fromRect:NSZeroRect
            operation:NSCompositeSourceOver
             fraction:(self.enabled) ? 1 : 0.5
       respectFlipped:YES
                hints:nil];
}

@end
