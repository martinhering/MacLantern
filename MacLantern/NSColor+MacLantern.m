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


#import "NSColor+MacLantern.h"

@implementation NSColor (MacLantern)

+(NSColor *)mlv_windowColor
{
    static dispatch_once_t once;
    static NSColor * mlv_windowColor;
    dispatch_once(&once, ^ {
        mlv_windowColor = [NSColor colorWithCalibratedWhite:0.0 alpha:1.0];
    });
    return mlv_windowColor;
};

+(NSColor *)mlv_panelColor
{
    static dispatch_once_t once;
    static NSColor * mlv_panelColor;
    dispatch_once(&once, ^ {
        mlv_panelColor = [NSColor colorWithCalibratedWhite:0.08 alpha:1.0];
    });
    return mlv_panelColor;
};

+(NSColor *)mlv_dividerColor
{
    static dispatch_once_t once;
    static NSColor * mlv_dividerColor;
    dispatch_once(&once, ^ {
        mlv_dividerColor = [NSColor colorWithDisplayP3Red:0.0 green:0.0 blue:0.0 alpha:1.0];
    });
    return mlv_dividerColor;
};

+(NSColor *)mlv_primaryColor
{
    static dispatch_once_t once;
    static NSColor * mlv_primaryColor;
    dispatch_once(&once, ^ {
        mlv_primaryColor = [NSColor colorWithCalibratedWhite:1.0 alpha:1.0];
    });
    return mlv_primaryColor;
};

+(NSColor *)mlv_secondaryColor
{
    static dispatch_once_t once;
    static NSColor * mlv_secondaryColor;
    dispatch_once(&once, ^ {
        mlv_secondaryColor = [NSColor colorWithDisplayP3Red:0.5 green:0.5 blue:0.5 alpha:1.0];
    });
    return mlv_secondaryColor;
};

+(NSColor *)mlv_selectionColor
{
    static dispatch_once_t once;
    static NSColor * mlv_selectionColor;
    dispatch_once(&once, ^ {
        mlv_selectionColor = [NSColor colorWithDisplayP3Red:0.102 green:0.549 blue:1.0 alpha:1.0];
    });
    return mlv_selectionColor;
};

+(NSColor *)mlv_controlBackgroundColor
{
    static dispatch_once_t once;
    static NSColor * mlv_controlBackgroundColor;
    dispatch_once(&once, ^ {
        mlv_controlBackgroundColor = [NSColor colorWithCalibratedWhite:0.2 alpha:1.0];
    });
    return mlv_controlBackgroundColor;
};

+(NSColor *)mlv_controlColor
{
    static dispatch_once_t once;
    static NSColor * mlv_controlColor;
    dispatch_once(&once, ^ {
        mlv_controlColor = [NSColor colorWithDisplayP3Red:1.0 green:1.0 blue:1.0 alpha:0.2];
    });
    return mlv_controlColor;
};

+(NSColor *)mlv_unfocusSelectionColor
{
    static dispatch_once_t once;
    static NSColor * mlv_unfocusSelectionColor;
    dispatch_once(&once, ^ {
        mlv_unfocusSelectionColor = [NSColor colorWithDisplayP3Red:0.25 green:0.25 blue:0.25 alpha:1.0];
    });
    return mlv_unfocusSelectionColor;
};

+(NSColor *)mlv_criticalColor
{
    static dispatch_once_t once;
    static NSColor * mlv_criticalColor;
    dispatch_once(&once, ^ {
        mlv_criticalColor = [NSColor colorWithDisplayP3Red:0.7438 green:0.0 blue:0.0 alpha:1.0];
    });
    return mlv_criticalColor;
};
@end
