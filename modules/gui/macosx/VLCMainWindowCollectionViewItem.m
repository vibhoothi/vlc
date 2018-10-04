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

#import "VLCMainWindowCollectionViewItem.h"

@interface VLCMainWindowCollectionViewItem ()
{
    
}
@end

@implementation VLCMainWindowCollectionViewItem

- (void)loadView {
    self.view = [[libraryView alloc] init];
    
    
    self.VLCItemImageView = [[NSImageView alloc] initWithFrame:self.view.bounds];
    self.VLCItemImageView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.view addSubview:self.VLCItemImageView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    [self.collectionView setDelegate:self];
}

-(void)setRepresentedObject:(id)representedObject{
    [super setRepresentedObject:representedObject];
    if (representedObject !=nil)
    {
        [self.imageView setImage:[[NSBundle mainBundle] imageForResource:[representedObject valueForKey:@"itemImage"]]];
    }
    
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


@end


@interface libraryView () {
 
}
@end


@implementation libraryView

@end
