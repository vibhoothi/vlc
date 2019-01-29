/*****************************************************************************
 * CustomAspectRatio.m: Panel for making custom aspect ratio
 *****************************************************************************
 * Copyright (C) 2019 VideoLAN and authors
 * Author:       Vibhoothi <vibhoothiiaanand at googlemail dot com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#import "VLCCustomAspectRatio.h"

@interface VLCCustomAspectRatio ()
{
    VLCCustomAspectRatioHandler _customAspectRatioHandler;
}

@end

@implementation VLCCustomAspectRatio

#pragma mark - object handling

- (id)init
{
    self = [super initWithWindowNibName:@"VLCCustomAspectRatio"];
    
    return self;
}

#pragma mark - UI handling

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

-(void) runModalForWindow:(NSWindow *)window completionHandler:(VLCCustomAspectRatioHandler)handler
{
    [self window];
    
    _customAspectRatioHandler = [handler copy];
    
    [window beginSheet:self.window completionHandler:nil];
}

@end
