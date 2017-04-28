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

#import "AppDelegate.h"
#import "MLVMainWindowController.h"
#import "MLVMainViewController.h"

#import <HockeySDK/HockeySDK.h>
#import <Sparkle/Sparkle.h>

@interface AppDelegate ()
@property (nonatomic, strong) MLVMainWindowController* mainWindowController;
@property (nonatomic, strong) MLVMainViewController* mainViewController;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"fe2f69973a8b496b89673b2d226abfd4"];
    [[BITHockeyManager sharedHockeyManager].crashManager setAutoSubmitCrashReport: YES];
    [[BITHockeyManager sharedHockeyManager] startManager];

    SUUpdater* updater = [SUUpdater sharedUpdater];
    [updater setAutomaticallyChecksForUpdates:YES];
    [updater setSendsSystemProfile:YES];
    updater.delegate = self;



    self.mainViewController = [MLVMainViewController viewController];

    self.mainWindowController = [MLVMainWindowController windowController];
    self.mainWindowController.contentViewController = self.mainViewController;

    [self.mainWindowController showWindow:nil];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

#pragma mark - Sparkle

- (void) _checkForUpdatesForce:(BOOL)force sender:(id)sender
{
    SUUpdater* updater = [SUUpdater sharedUpdater];
    [updater setDelegate:self];

    NSDate* lastUpdateCheck = [updater lastUpdateCheckDate];

    if (force) {
        [updater checkForUpdates:nil];
    }
    else if ([lastUpdateCheck timeIntervalSinceNow] < -86400) {
        [updater checkForUpdatesInBackground];
    }
}

- (IBAction) checkForUpdates:(id)sender {
    [self _checkForUpdatesForce:YES sender:sender];
}

- (NSArray *)feedParametersForUpdater:(SUUpdater *)updater sendingSystemProfile:(BOOL)sendingProfile {
    return [[BITSystemProfile sharedSystemProfile] systemUsageData];
}
@end
