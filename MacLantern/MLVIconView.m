//
//  MLVIconView.m
//  MacLantern
//
//  Created by Martin Hering on 30.04.17.
//  Copyright © 2017 Martin Hering. All rights reserved.
//

#import "MLVIconView.h"
#import "NSImage+MacLantern.h"
#import "NSColor+MacLantern.h"

@implementation MLVIconView

- (void) awakeFromNib
{
    [super awakeFromNib];

    self.image = [self.image imageWithColor:[NSColor mlv_controlColor]];
}


@end
