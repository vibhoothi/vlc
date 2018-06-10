/*****************************************************************************
 * VLCMainWindow.m: MacOS X interface module
 *****************************************************************************
 * Copyright (C) 2002-2013 VLC authors and VideoLAN
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

#import "VLCMainWindow.h"

#import "VLCMain.h"
#import "CompatibilityFixes.h"
#import "VLCCoreInteraction.h"
#import "VLCAudioEffectsWindowController.h"
#import "VLCMainMenu.h"
#import "VLCOpenWindowController.h"
#import "VLCPlaylist.h"
#import "SideBarItem.h"
#import <math.h>
#import <vlc_playlist.h>
#import <vlc_url.h>
#import <vlc_strings.h>
#import <vlc_services_discovery.h>
#import "VLCPLModel.h"

#import "PXSourceList.h"
#import "PXSourceListDataSource.h"

#import "VLCMainWindowControlsBar.h"
#import "VLCVoutView.h"
#import "VLCVideoOutputProvider.h"


@interface VLCMainWindow() <PXSourceListDataSource, PXSourceListDelegate, NSOutlineViewDataSource, NSOutlineViewDelegate, NSWindowDelegate, NSAnimationDelegate>
{
    BOOL videoPlaybackEnabled;
    BOOL dropzoneActive;
    BOOL minimizedView;

    BOOL b_video_playback_enabled;
    BOOL b_dropzone_active;
    BOOL b_splitview_removed;
    BOOL b_minimized_view;
    CGFloat f_lastSplitViewHeight;
    CGFloat f_lastLeftSplitViewWidth;



    /* this is only true, when we have NO video playing inside the main window */



    NSRect frameBeforePlayback;
}


@end

static const float f_min_window_height = 307.;

@implementation VLCMainWindow

#pragma mark -
#pragma mark Initialization

- (BOOL)isEvent:(NSEvent *)o_event forKey:(const char *)keyString
{
    char *key;
    NSString *o_key;

    key = config_GetPsz(keyString);
    o_key = [NSString stringWithFormat:@"%s", key];
    FREENULL(key);

    unsigned int i_keyModifiers = [[VLCStringUtility sharedInstance] VLCModifiersToCocoa:o_key];

    NSString * characters = [o_event charactersIgnoringModifiers];
    if ([characters length] > 0) {
        return [[characters lowercaseString] isEqualToString: [[VLCStringUtility sharedInstance] VLCKeyToString: o_key]] &&
                (i_keyModifiers & NSShiftKeyMask)     == ([o_event modifierFlags] & NSShiftKeyMask) &&
                (i_keyModifiers & NSControlKeyMask)   == ([o_event modifierFlags] & NSControlKeyMask) &&
                (i_keyModifiers & NSAlternateKeyMask) == ([o_event modifierFlags] & NSAlternateKeyMask) &&
                (i_keyModifiers & NSCommandKeyMask)   == ([o_event modifierFlags] & NSCommandKeyMask);
    }
    return NO;
}

- (BOOL)performKeyEquivalent:(NSEvent *)o_event
{
    BOOL b_force = NO;
    // these are key events which should be handled by vlc core, but are attached to a main menu item
    if (![self isEvent: o_event forKey: "key-vol-up"] &&
        ![self isEvent: o_event forKey: "key-vol-down"] &&
        ![self isEvent: o_event forKey: "key-vol-mute"] &&
        ![self isEvent: o_event forKey: "key-prev"] &&
        ![self isEvent: o_event forKey: "key-next"] &&
        ![self isEvent: o_event forKey: "key-jump+short"] &&
        ![self isEvent: o_event forKey: "key-jump-short"]) {
        /* We indeed want to prioritize some Cocoa key equivalent against libvlc,
         so we perform the menu equivalent now. */
        if ([[NSApp mainMenu] performKeyEquivalent:o_event])
            return TRUE;
    }
    else
        b_force = YES;

    VLCCoreInteraction *coreInteraction = [VLCCoreInteraction sharedInstance];
    return [coreInteraction hasDefinedShortcutKey:o_event force:b_force] ||
           [coreInteraction keyEvent:o_event];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void)awakeFromNib
{
    [super awakeFromNib];

    /*
     * General setup
     */

    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];


    [self setDelegate:self];
    [self setRestorable:NO];
    [self setExcludedFromWindowsMenu:YES];
    [self setAcceptsMouseMovedEvents:YES];
    [self setFrameAutosaveName:@"mainwindow"];

    _nativeFullscreenMode = var_InheritBool(getIntf(), "macosx-nativefullscreenmode");
    b_dropzone_active = YES;

    // Playlist setup
    VLCPlaylist *playlist = [[VLCMain sharedInstance] playlist];
    [playlist setOutlineView:(VLCPlaylistView *)_outlineView];
    [playlist setPlaylistHeaderView:_outlineView.headerView];
    [self setNextResponder:playlist];




    /*
     * Set up translatable strings for the UI elements
     */

    // Window title
    [self setTitle:_NS("VLC media player")];

    // Search Field
    [_searchField setToolTip:_NS("Search in Playlist")];
    [_searchField.cell setPlaceholderString:_NS("Search")];
    [_searchField.cell accessibilitySetOverrideValue:_NS("Search the playlist. Results will be selected in the table.")
                                        forAttribute:NSAccessibilityDescriptionAttribute];

    // Dropzone
    [_dropzoneLabel setStringValue:_NS("Drop media here")];
    [_dropzoneImageView setImage:imageFromRes(@"dropzone")];
    [_dropzoneButton setTitle:_NS("Open media...")];
    [_dropzoneButton.cell accessibilitySetOverrideValue:_NS("Open a dialog to select the media to play")
                                           forAttribute:NSAccessibilityDescriptionAttribute];



    /* interface builder action */
    CGFloat f_threshold_height = f_min_video_height + [self.controlsBar height];


    // Set that here as IB seems to be buggy
    [self setContentMinSize:NSMakeSize(604., f_min_window_height)];

    _fspanel = [[VLCFSPanelController alloc] init];
    [_fspanel showWindow:self];

    /* make sure we display the desired default appearance when VLC launches for the first time */
    if (![defaults objectForKey:@"VLCFirstRun"]) {
        [defaults setObject:[NSDate date] forKey:@"VLCFirstRun"];


        NSAlert *albumArtAlert = [[NSAlert alloc] init];
        [albumArtAlert setMessageText:_NS("Check for album art and metadata?")];
        [albumArtAlert setInformativeText:_NS("VLC can check online for album art and metadata to enrich your playback experience, e.g. by providing track information when playing Audio CDs. To provide this functionality, VLC will send information about your contents to trusted services in an anonymized form.")];
        [albumArtAlert addButtonWithTitle:_NS("Enable Metadata Retrieval")];
        [albumArtAlert addButtonWithTitle:_NS("No, Thanks")];

        NSInteger returnValue = [albumArtAlert runModal];
        config_PutInt("metadata-network-access", returnValue == NSAlertFirstButtonReturn);
    }

    [_playlistScrollView setBorderType:NSNoBorder];

    [defaultCenter addObserver: self selector: @selector(someWindowWillClose:) name: NSWindowWillCloseNotification object: nil];
    [defaultCenter addObserver: self selector: @selector(someWindowWillMiniaturize:) name: NSWindowWillMiniaturizeNotification object:nil];
    [defaultCenter addObserver: self selector: @selector(applicationWillTerminate:) name: NSApplicationWillTerminateNotification object: nil];

    /* sanity check for the window size */
    NSRect frame = [self frame];
    NSSize screenSize = [[self screen] frame].size;
    if (screenSize.width <= frame.size.width || screenSize.height <= frame.size.height) {
        self.nativeVideoSize = screenSize;
        [self resizeWindow];
    }

    /* update fs button to reflect state for next startup */
    if (var_InheritBool(pl_Get(getIntf()), "fullscreen"))
        [self.controlsBar setFullscreenState:YES];


}

- (void)changePlaylistState:(VLCPlaylistStateEvent)event
{
    // Beware, this code is really ugly

    msg_Dbg(getIntf(), "toggle playlist from state: minimized view %i. Event %i", b_minimized_view, event);
    if (![self isVisible] && event == psUserMenuEvent) {
        [self makeKeyAndOrderFront: nil];
        return;
    }

    BOOL b_activeVideo = [[VLCMain sharedInstance] activeVideoPlayback];
    BOOL b_restored = NO;

    // ignore alt if triggered through main menu shortcut
    BOOL b_have_alt_key = ([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0;
    if (event == psUserMenuEvent)
        b_have_alt_key = NO;

    // eUserMenuEvent is now handled same as eUserEvent
    if(event == psUserMenuEvent)
        event = psUserEvent;

    if (b_dropzone_active && b_have_alt_key) {
        [self hideDropZone];
        return;
    }

    if (!(self.nativeFullscreenMode && self.fullscreen) && ((b_have_alt_key && b_activeVideo)
                                                                              || (self.nonembedded && event == psUserEvent)
                                                                              || (!b_activeVideo && event == psUserEvent)
                                                                              || (b_minimized_view && event == psVideoStartedOrStoppedEvent))) {
        // for starting playback, window is resized through resized events
        // for stopping playback, resize through reset to previous frame
        [self hideSplitView: event != psVideoStartedOrStoppedEvent];
        b_minimized_view = NO;
    }
    msg_Dbg(getIntf(), "toggle playlist to state: minimized view %i", b_minimized_view);
}

- (IBAction)dropzoneButtonAction:(id)sender
{
    [[[VLCMain sharedInstance] open] openFileGeneric];
}

#pragma mark -
#pragma mark overwritten default functionality

- (void)windowResizedOrMoved:(NSNotification *)notification
{
    [self saveFrameUsingName:[self frameAutosaveName]];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    [self saveFrameUsingName:[self frameAutosaveName]];
}


- (void)someWindowWillClose:(NSNotification *)notification
{
    id obj = [notification object];

    // hasActiveVideo is defined for VLCVideoWindowCommon and subclasses
    if ([obj respondsToSelector:@selector(hasActiveVideo)] && [obj hasActiveVideo]) {
        if ([[VLCMain sharedInstance] activeVideoPlayback])
            [[VLCCoreInteraction sharedInstance] stop];
    }
}

- (void)someWindowWillMiniaturize:(NSNotification *)notification
{
    if (config_GetInt("macosx-pause-minimized")) {
        id obj = [notification object];

        if ([obj class] == [VLCVideoWindowCommon class] || [obj class] == [VLCDetachedVideoWindow class] || ([obj class] == [VLCMainWindow class] && !self.nonembedded)) {
            if ([[VLCMain sharedInstance] activeVideoPlayback])
                [[VLCCoreInteraction sharedInstance] pause];
        }
    }
}

#pragma mark -
#pragma mark Update interface and respond to foreign events
- (void)showDropZone
{
    b_dropzone_active = YES;
    [_dropzoneView setHidden:NO];
    [_playlistScrollView setHidden:YES];
}

- (void)hideDropZone
{
    b_dropzone_active = NO;
    [_dropzoneView setHidden:YES];
    [_playlistScrollView setHidden:NO];
}

- (void)hideSplitView:(BOOL)resize
{
    if (resize) {
        NSRect winrect = [self frame];
        f_lastSplitViewHeight = [_splitView frame].size.height;
        winrect.size.height = winrect.size.height - f_lastSplitViewHeight;
        winrect.origin.y = winrect.origin.y + f_lastSplitViewHeight;
        [self setFrame:winrect display:YES animate:YES];
    }

    [self setContentMinSize: NSMakeSize(604., [self.controlsBar height])];
    [self setContentMaxSize: NSMakeSize(FLT_MAX, [self.controlsBar height])];

    b_splitview_removed = YES;
}

- (void)showSplitView:(BOOL)resize
{
    [self updateWindow];
    [self setContentMinSize:NSMakeSize(604., f_min_window_height)];
    [self setContentMaxSize: NSMakeSize(FLT_MAX, FLT_MAX)];

    if (resize) {
        NSRect winrect;
        winrect = [self frame];
        winrect.size.height = winrect.size.height + f_lastSplitViewHeight;
        winrect.origin.y = winrect.origin.y - f_lastSplitViewHeight;
        [self setFrame:winrect display:YES animate:YES];
    }

    b_splitview_removed = NO;
}

- (void)updateTimeSlider
{
    [self.controlsBar updateTimeSlider];
    [self.fspanel updatePositionAndTime];

    [[[VLCMain sharedInstance] voutProvider] updateControlsBarsUsingBlock:^(VLCControlsBarCommon *controlsBar) {
        [controlsBar updateTimeSlider];
    }];

    [[VLCCoreInteraction sharedInstance] updateAtoB];
}

- (void)updateName
{
    input_thread_t *p_input;
    p_input = pl_CurrentInput(getIntf());
    if (p_input) {
        NSString *aString = @"";

        if (!config_GetPsz("video-title")) {
            char *format = var_InheritString(getIntf(), "input-title-format");
            if (format) {
                char *formated = vlc_strfinput(p_input, format);
                free(format);
                aString = toNSStr(formated);
                free(formated);
            }
        } else
            aString = toNSStr(config_GetPsz("video-title"));

        char *uri = input_item_GetURI(input_GetItem(p_input));

        NSURL * o_url = [NSURL URLWithString:toNSStr(uri)];
        if ([o_url isFileURL]) {
            [self setRepresentedURL: o_url];
            [[[VLCMain sharedInstance] voutProvider] updateWindowsUsingBlock:^(VLCVideoWindowCommon *o_window) {
                [o_window setRepresentedURL:o_url];
            }];
        } else {
            [self setRepresentedURL: nil];
            [[[VLCMain sharedInstance] voutProvider] updateWindowsUsingBlock:^(VLCVideoWindowCommon *o_window) {
                [o_window setRepresentedURL:nil];
            }];
        }
        free(uri);

        if ([aString isEqualToString:@""]) {
            if ([o_url isFileURL])
                aString = [[NSFileManager defaultManager] displayNameAtPath: [o_url path]];
            else
                aString = [o_url absoluteString];
        }

        if ([aString length] > 0) {
            [self setTitle: aString];
            [[[VLCMain sharedInstance] voutProvider] updateWindowsUsingBlock:^(VLCVideoWindowCommon *o_window) {
                [o_window setTitle:aString];
            }];

            [self.fspanel setStreamTitle: aString];
        } else {
            [self setTitle: _NS("VLC media player")];
            [self setRepresentedURL: nil];
        }

        vlc_object_release(p_input);
    } else {
        [self setTitle: _NS("VLC media player")];
        [self setRepresentedURL: nil];
    }
}

- (void)updateWindow
{
    [self.controlsBar updateControls];
    [[[VLCMain sharedInstance] voutProvider] updateControlsBarsUsingBlock:^(VLCControlsBarCommon *controlsBar) {
        [controlsBar updateControls];
    }];

    bool b_seekable = false;

    playlist_t *p_playlist = pl_Get(getIntf());
    input_thread_t *p_input = playlist_CurrentInput(p_playlist);
    if (p_input) {
        /* seekable streams */
        b_seekable = var_GetBool(p_input, "can-seek");

        vlc_object_release(p_input);
    }

    [self updateTimeSlider];
    if ([self.fspanel respondsToSelector:@selector(setSeekable:)])
        [self.fspanel setSeekable: b_seekable];

    PL_LOCK;
    if ([[[[VLCMain sharedInstance] playlist] model] currentRootType] != ROOT_TYPE_PLAYLIST ||
        [[[[VLCMain sharedInstance] playlist] model] hasChildren])
        [self hideDropZone];
    else
        [self showDropZone];
    PL_UNLOCK;

    [self _updatePlaylistTitle];
}

- (void)setPause
{
    [self.controlsBar setPause];
    [self.fspanel setPause];

    [[[VLCMain sharedInstance] voutProvider] updateControlsBarsUsingBlock:^(VLCControlsBarCommon *controlsBar) {
        [controlsBar setPause];
    }];
}

- (void)setPlay
{
    [self.controlsBar setPlay];
    [self.fspanel setPlay];

    [[[VLCMain sharedInstance] voutProvider] updateControlsBarsUsingBlock:^(VLCControlsBarCommon *controlsBar) {
        [controlsBar setPlay];
    }];
}

- (void)updateVolumeSlider
{
    [(VLCMainWindowControlsBar *)[self controlsBar] updateVolumeSlider];
    [self.fspanel setVolumeLevel:[[VLCCoreInteraction sharedInstance] volume]];
}

#pragma mark -
#pragma mark Video Output handling

- (void)videoplayWillBeStarted
{
    if (!self.fullscreen)
        frameBeforePlayback = [self frame];
}

- (void)setVideoplayEnabled
{
    BOOL b_videoPlayback = [[VLCMain sharedInstance] activeVideoPlayback];

    if (!b_videoPlayback) {
        if (!self.nonembedded && (!self.nativeFullscreenMode || (self.nativeFullscreenMode && !self.fullscreen)) && frameBeforePlayback.size.width > 0 && frameBeforePlayback.size.height > 0) {

            // only resize back to minimum view of this is still desired final state
            CGFloat f_threshold_height = f_min_video_height + [self.controlsBar height];
            if(frameBeforePlayback.size.height > f_threshold_height || b_minimized_view) {

                if ([[VLCMain sharedInstance] isTerminating])
                    [self setFrame:frameBeforePlayback display:YES];
                else
                    [[self animator] setFrame:frameBeforePlayback display:YES];

            }
        }

        frameBeforePlayback = NSMakeRect(0, 0, 0, 0);

        // update fs button to reflect state for next startup
        if (var_InheritBool(getIntf(), "fullscreen") || var_GetBool(pl_Get(getIntf()), "fullscreen")) {
            [self.controlsBar setFullscreenState:YES];
        }

        [self makeFirstResponder: _playlistScrollView];
        [[[VLCMain sharedInstance] voutProvider] updateWindowLevelForHelperWindows: NSNormalWindowLevel];

        // restore alpha value to 1 for the case that macosx-opaqueness is set to < 1
        [self setAlphaValue:1.0];
    }

    if (self.nativeFullscreenMode) {
        if ([self hasActiveVideo] && [self fullscreen] && b_videoPlayback) {
            [self hideControlsBar];
            [self.fspanel setActive];
        } else {
            [self showControlsBar];
            [self.fspanel setNonActive];
        }
    }
}

#pragma mark -
#pragma mark Fullscreen support

- (void)showFullscreenController
{
    id currentWindow = [NSApp keyWindow];
    if ([currentWindow respondsToSelector:@selector(hasActiveVideo)] && [currentWindow hasActiveVideo]) {
        if ([currentWindow respondsToSelector:@selector(fullscreen)] && [currentWindow fullscreen] && ![[currentWindow videoView] isHidden]) {

            if ([[VLCMain sharedInstance] activeVideoPlayback])
                [self.fspanel fadeIn];
        }
    }

}

#pragma mark -
#pragma mark split view delegate
- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)dividerIndex
{
    if (dividerIndex == 0)
        return 300.;
    else
        return proposedMax;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)dividerIndex
{
    if (dividerIndex == 0)
        return 100.;
    else
        return proposedMin;
}

- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview
{
    return ([subview isEqual:_splitViewLeft]);
}

- (BOOL)splitView:(NSSplitView *)splitView shouldAdjustSizeOfSubview:(NSView *)subview
{
    return (![subview isEqual:_splitViewLeft]);
}

- (void)mainSplitViewDidResizeSubviews:(id)object
{
    f_lastLeftSplitViewWidth = [_splitViewLeft frame].size.width;
    [[[VLCMain sharedInstance] mainMenu] updateSidebarMenuItem: ![_splitView isSubviewCollapsed:_splitViewLeft]];
}

- (void)toggleLeftSubSplitView
{
    [_splitView adjustSubviews];
    if ([_splitView isSubviewCollapsed:_splitViewLeft])
        [_splitView setPosition:f_lastLeftSplitViewWidth ofDividerAtIndex:0];
    else
        [_splitView setPosition:[_splitView minPossiblePositionOfDividerAtIndex:0] ofDividerAtIndex:0];

}

#pragma mark -
#pragma mark private playlist magic
- (void)_updatePlaylistTitle
{
    PLRootType root = [[[[VLCMain sharedInstance] playlist] model] currentRootType];
    playlist_t *p_playlist = pl_Get(getIntf());

    PL_LOCK;
    if (root == ROOT_TYPE_PLAYLIST)
        [_categoryLabel setStringValue: [_NS("Playlist") stringByAppendingString:[self _playbackDurationOfNode:p_playlist->p_playing]]];
    else if (root == ROOT_TYPE_MEDIALIBRARY)
        [_categoryLabel setStringValue: [_NS("Media Library") stringByAppendingString:[self _playbackDurationOfNode:p_playlist->p_media_library]]];

    PL_UNLOCK;
}

- (NSString *)_playbackDurationOfNode:(playlist_item_t*)node
{
    if (!node)
        return @"";

    playlist_t * p_playlist = pl_Get(getIntf());
    PL_ASSERT_LOCKED;

    mtime_t mt_duration = playlist_GetNodeDuration( node );

    if (mt_duration < 1)
        return @"";

    mt_duration = mt_duration / CLOCK_FREQ;

    NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
    formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleAbbreviated;

    NSString* outputString = [formatter stringFromTimeInterval:mt_duration];

    return [NSString stringWithFormat:@" — %@", outputString];
}

- (IBAction)searchItem:(id)sender
{
    [[[[VLCMain sharedInstance] playlist] model] searchUpdate:[_searchField stringValue]];
}

- (IBAction)highlightSearchField:(id)sender
{
    [_searchField selectText:sender];
}

- (id)sourceList:(PXSourceList*)aSourceList objectValueForItem:(id)item
{
    return [item title];
}

- (void)sourceList:(PXSourceList*)aSourceList setObjectValue:(id)object forItem:(id)item
{
    [item setTitle:object];
}

- (BOOL)sourceList:(PXSourceList*)aSourceList isItemExpandable:(id)item
{
    return [item hasChildren];
}


- (BOOL)sourceList:(PXSourceList*)aSourceList itemHasBadge:(id)item
{
    if ([[item identifier] isEqualToString: @"playlist"] || [[item identifier] isEqualToString: @"medialibrary"])
        return YES;

    return [item hasBadge];
}


- (NSInteger)sourceList:(PXSourceList*)aSourceList badgeValueForItem:(id)item
{
    playlist_t * p_playlist = pl_Get(getIntf());
    NSInteger i_playlist_size = 0;

    if ([[item identifier] isEqualToString: @"playlist"]) {
        PL_LOCK;
        i_playlist_size = p_playlist->p_playing->i_children;
        PL_UNLOCK;

        return i_playlist_size;
    }
    if ([[item identifier] isEqualToString: @"medialibrary"]) {
        PL_LOCK;
        if (p_playlist->p_media_library)
            i_playlist_size = p_playlist->p_media_library->i_children;
        PL_UNLOCK;

        return i_playlist_size;
    }

    return [item badgeValue];
}


- (BOOL)sourceList:(PXSourceList*)aSourceList itemHasIcon:(id)item
{
    return [item hasIcon];
}


- (NSImage*)sourceList:(PXSourceList*)aSourceList iconForItem:(id)item
{
    return [item icon];
}

- (NSMenu*)sourceList:(PXSourceList*)aSourceList menuForEvent:(NSEvent*)theEvent item:(id)item
{
    if ([theEvent type] == NSRightMouseDown || ([theEvent type] == NSLeftMouseDown && ([theEvent modifierFlags] & NSControlKeyMask) == NSControlKeyMask)) {
        if (item != nil) {
            if ([item sdtype] > 0)
            {
                NSMenu *m = [[NSMenu alloc] init];
                playlist_t * p_playlist = pl_Get(getIntf());
                BOOL sd_loaded = playlist_IsServicesDiscoveryLoaded(p_playlist, [[item identifier] UTF8String]);
                if (!sd_loaded)
                    [m addItemWithTitle:_NS("Enable") action:@selector(sdmenuhandler:) keyEquivalent:@""];
                else
                    [m addItemWithTitle:_NS("Disable") action:@selector(sdmenuhandler:) keyEquivalent:@""];
                [[m itemAtIndex:0] setRepresentedObject: [item identifier]];
                return m;
            }
        }
    }

    return nil;
}

- (IBAction)sdmenuhandler:(id)sender
{
    NSString * identifier = [sender representedObject];
    if ([identifier length] > 0 && ![identifier isEqualToString:@"lua{sd='freebox',longname='Freebox TV'}"]) {
        playlist_t * p_playlist = pl_Get(getIntf());
        BOOL sd_loaded = playlist_IsServicesDiscoveryLoaded(p_playlist, [identifier UTF8String]);

        if (!sd_loaded)
            playlist_ServicesDiscoveryAdd(p_playlist, [identifier UTF8String]);
        else
            playlist_ServicesDiscoveryRemove(p_playlist, [identifier UTF8String]);
    }
}

- (NSDragOperation)sourceList:(PXSourceList *)aSourceList validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)index
{
    if ([[item identifier] isEqualToString:@"playlist"] || [[item identifier] isEqualToString:@"medialibrary"]) {
        NSPasteboard *o_pasteboard = [info draggingPasteboard];
        if ([[o_pasteboard types] containsObject: VLCPLItemPasteboadType] || [[o_pasteboard types] containsObject: NSFilenamesPboardType])
            return NSDragOperationGeneric;
    }
    return NSDragOperationNone;
}

- (BOOL)sourceList:(PXSourceList *)aSourceList acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)index
{
    NSPasteboard *o_pasteboard = [info draggingPasteboard];

    playlist_t * p_playlist = pl_Get(getIntf());
    playlist_item_t *p_node;

    if ([[item identifier] isEqualToString:@"playlist"])
        p_node = p_playlist->p_playing;
    else
        p_node = p_playlist->p_media_library;

    if ([[o_pasteboard types] containsObject: @"VLCPlaylistItemPboardType"]) {
        NSArray * array = [[[VLCMain sharedInstance] playlist] draggedItems];

        NSUInteger count = [array count];

        PL_LOCK;
        for(NSUInteger i = 0; i < count; i++) {
            playlist_item_t *p_item = playlist_ItemGetById(p_playlist, [[array objectAtIndex:i] plItemId]);
            if (!p_item) continue;
            playlist_NodeAddCopy(p_playlist, p_item, p_node, PLAYLIST_END);
        }
        PL_UNLOCK;

        return YES;
    }

    // check if dropped item is a file
    NSArray *items = [[[VLCMain sharedInstance] playlist] createItemsFromExternalPasteboard:o_pasteboard];
    if (items.count == 0)
        return NO;

    [[[VLCMain sharedInstance] playlist] addPlaylistItems:items
                                         withParentItemId:p_node->i_id
                                                    atPos:-1
                                            startPlayback:NO];
    return YES;
}

- (id)sourceList:(PXSourceList *)aSourceList persistentObjectForItem:(id)item
{
    return [item identifier];
}

@end

@interface VLCDetachedVideoWindow ()
@end

@implementation VLCDetachedVideoWindow

- (void)awakeFromNib
{
    // sets lion fullscreen behaviour
    [super awakeFromNib];
    [self setAcceptsMouseMovedEvents: YES];

    [self setContentMinSize: NSMakeSize(363., f_min_video_height + [[self controlsBar] height])];
}

@end
