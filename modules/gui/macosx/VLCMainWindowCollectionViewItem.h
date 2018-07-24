/*****************************************************************************
 * VLCMainWindowCollectionView.h: MacOS X interface module
 *****************************************************************************
 * Copyright (C) 2018 VLC authors and VideoLAN
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

@interface VLCMainWindowCollectionViewItem : NSCollectionViewItem < NSCollectionViewDelegate>
@property (nonatomic,strong) IBOutlet NSImageView *VLCItemImageView;
@property (strong) IBOutlet NSPopover *VLCPopOver;
@property (unsafe_unretained) IBOutlet NSButton *VLCPopOverTriggerButton;
@property (nonatomic,strong) IBOutlet NSTextField *VLCItemLabel;

@end

@interface libraryView : NSView

@end
 
