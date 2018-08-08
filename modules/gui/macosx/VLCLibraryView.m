/*****************************************************************************
 * VLCMainWindowCollectionView.m: MacOS X interface module
 *****************************************************************************
 * Copyright (C) 2002-2018 VLC authors and VideoLAN
 * $Id $
 *
 * Authors: Vibhoothi   <vibhoothiiaanand -at- googlemail dot com>
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

#import <Cocoa/Cocoa.h>
#import "VLCLibraryView.h"
#import "VLCLibraryItem.h"

@interface VLCLibraryView ()
{
    
}
@end

@implementation VLCLibraryView

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    [self.collectionView setDelegate:self];
}

-(void)assignValueForDataModel:(VLCLibraryItem *) dataModel
{
    NSLog(@"dataModel %@",dataModel);
    self.VLCItemLabel.stringValue =dataModel.videoTitle;;
    self.VLCItemImageView.image=dataModel.thumbnail;
    self.popOverYear.stringValue = dataModel.year;
    self.popOverImage=self.VLCItemImageView;
    self.popOverTitle=self.VLCItemLabel;
}

- (void)setSelected:(BOOL)flag
{
    [super setSelected:flag];
    [self updateBackgroundColorForSelectionState:flag];
}


- (void) viewDidAppear
{
    [self updateBackgroundColorForSelectionState:self.isSelected];
}
- (void)updateBackgroundColorForSelectionState:(BOOL)flag
{
    if (flag)
    {
        self.view.layer.backgroundColor = [[NSColor alternateSelectedControlColor] CGColor];
    }
    else
    {
        self.view.layer.backgroundColor = [[NSColor clearColor] CGColor];
    }
}

- (BOOL)buttonIsPressed
{
    return self.VLCPopOverTriggerButton.intValue == 1;
}

- (IBAction)popOver:(id)sender {
    NSLog(@"VLC: Popup tapped");
        if (self.buttonIsPressed)
        {
            [self.VLCPopOver showRelativeToRect:[self.VLCPopOverTriggerButton bounds] ofView:self.VLCPopOverTriggerButton preferredEdge:NSMaxYEdge];
        } else {
            [self.VLCPopOver close];
        }
}


@end

