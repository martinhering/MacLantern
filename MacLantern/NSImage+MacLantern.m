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
#import "NSImage+MacLantern.h"

@implementation NSImage (MacLantern)

- (NSImage *) imageWithColor:(NSColor *)aColor
{
    NSImage * aMaskImage = self;

    NSSize aSize = [aMaskImage size];
    NSImage * aDestImage = [[NSImage alloc] initWithSize:[aMaskImage size]];
    [aDestImage lockFocus];
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];

    /// draw here

    [aColor set];
    NSRect aRect = NSZeroRect;
    aRect.size = aSize;
    [[NSBezierPath bezierPathWithRect:aRect] fill];

    // end draw


    //[aMaskImage compositeToPoint:NSZeroPoint operation:NSCompositeDestinationAtop];

    [aMaskImage drawInRect:aRect fromRect:NSZeroRect operation:NSCompositeDestinationAtop fraction:1.0 respectFlipped:YES hints:nil];

    [aDestImage unlockFocus];
    return aDestImage;
    
}

@end
