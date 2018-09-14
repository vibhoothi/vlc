/*****************************************************************************
 * VLCMainWindow.h: MacOS X interface module
 *****************************************************************************
 * Copyright (C) 2002-2018 VLC authors and VideoLAN
 * $Id$
 *
 * Authors: Felix Paul Kühne <fkuehne -at- videolan -dot- org>
 *          Jon Lech Johansen <jon-vl@nanocrew.net>
 *          Christophe Massiot <massiot@via.ecp.fr>
 *          Derk-Jan Hartman <hartman at videolan.org>
 *          David Fuhrmann <david dot fuhrmann at googlemail dot com>
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
#import <AVFoundation/AVFoundation.h>
#import <vlc_input.h>
#import <vlc_vout_window.h>

#import "VLCVideoWindowCommon.h"
#import "misc.h"
#import "VLCFSPanelController.h"
#import "VLCLibraryView.h"
#import "VLCPlayQueue.h"

@class VLCDetachedVideoWindow;
@class VLCMainWindowControlsBar;
@class VLCVoutView;

typedef enum {
    psUserEvent,
    psUserMenuEvent,
    psVideoStartedOrStoppedEvent,
    psPlaylistItemChangedEvent
} VLCPlaylistStateEvent;

@interface VLCMainWindow : VLCVideoWindowCommon

@property (readonly) BOOL nativeFullscreenMode;
@property (readwrite) BOOL nonembedded;
@property (weak) IBOutlet NSCollectionView *collectionView;
@property (weak) IBOutlet NSCollectionView *playQueueView;
@property (strong) VLCLibraryItem *dataModel;
@property (strong) NSMutableArray *dummyData;
@property (readonly) VLCFSPanelController* fspanel;
@property (nonatomic, copy) NSDictionary *overrideClassNames;
@property (nonatomic, weak) IBOutlet VLCTopBarView* topView;
@property (readwrite,strong) IBOutlet NSButton *playQueueButton;
@property (strong) IBOutlet  NSPopover *playQueuePopOver;



- (void)changePlaylistState:(VLCPlaylistStateEvent)event;
- (void) addItemsToPlayQueue:(NSSet<NSIndexPath *>  *) indexPath;

- (void)windowResizedOrMoved:(NSNotification *)notification;

- (void)updateTimeSlider;
- (void)updateWindow;
- (void)updateName;
- (void)setPause;
- (void)setPlay;
- (void)updateVolumeSlider;

- (void)showFullscreenController;

- (void)videoplayWillBeStarted;
- (void)setVideoplayEnabled;

@end

@interface VLCDetachedVideoWindow : VLCVideoWindowCommon

@end
