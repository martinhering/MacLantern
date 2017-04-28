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

#import "MLVMainWindowController.h"
#import "NSColor+MacLantern.h"

@interface MLVMainWindowController ()
@property (weak) IBOutlet NSToolbar* toolbar;
@property (weak) IBOutlet NSToolbarItem* toolbarItem;
@property (weak) IBOutlet NSView* titlebarHostView;
@end

@implementation MLVMainWindowController

+ (instancetype) windowController {
    return [[self alloc] initWithWindowNibName:@"MainWindow"];
}

- (void)windowDidLoad {
    [super windowDidLoad];

    NSWindow* window = self.window;
    window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
    window.backgroundColor = [NSColor mlv_panelColor];
    window.titleVisibility = NSWindowTitleHidden;
    window.colorSpace = [NSColorSpace displayP3ColorSpace];

    NSString* frameString = [[NSUserDefaults standardUserDefaults] objectForKey:@"MainWindowFrame"];
    if (frameString) {
        [self.window setFrame:NSRectFromString(frameString) display:NO];
    }

    [self _updateToolbarView];
}

- (void) _updateToolbarView
{
    NSView* toolbarItemViewer = self.titlebarHostView.superview;
    NSView* toolbarViewClipView = toolbarItemViewer.superview;
    NSRect toolbarViewClipViewRect = toolbarViewClipView.frame;

    self.toolbarItem.minSize = toolbarViewClipViewRect.size;
    self.toolbarItem.maxSize = toolbarViewClipViewRect.size;
    self.titlebarHostView.frame = toolbarItemViewer.bounds;
}

- (void)windowDidResize:(NSNotification *)notification {
    if (self.window.visible) {
        [self _updateToolbarView];

        [[NSUserDefaults standardUserDefaults] setObject:NSStringFromRect(self.window.frame) forKey:@"MainWindowFrame"];
    }
}

@end
