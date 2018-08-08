/*****************************************************************************
 * VLCMainWindow.m: MacOS X interface module
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

#import "VLCMainWindow.h"

#import "VLCMain.h"
#import "CompatibilityFixes.h"
#import "VLCCoreInteraction.h"
#import "VLCAudioEffectsWindowController.h"
#import "VLCMainMenu.h"
#import "VLCOpenWindowController.h"
#import "VLCPlaylist.h"
#import <math.h>
#import <vlc_playlist.h>
#import <vlc_url.h>
#import <vlc_strings.h>
#import <vlc_services_discovery.h>
#import "VLCPLModel.h"

#import "VLCMainWindowControlsBar.h"
#import "VLCVoutView.h"
#import "VLCVideoOutputProvider.h"

@interface VLCMainWindow() <NSWindowDelegate, NSAnimationDelegate, NSCollectionViewDelegate,NSCollectionViewDataSource>
{
    BOOL videoPlaybackEnabled;
    BOOL dropzoneActive;
    BOOL minimizedView;
    BOOL collectionViewRemoved;
    NSSet<NSIndexPath *> * VLCLibraryViewItem;
    CGFloat lastCollectionViewHeight;
    NSRect frameBeforePlayback;
}
@end

static const float f_min_window_height = 307.;

@implementation VLCMainWindow

#pragma mark -
#pragma mark Initialization

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

    /*
     * Set up translatable strings for the UI elements
     */

    // Window title
    [self setTitle:_NS("VLC media player")];

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

    /* Initialise collectionview  when Player loads  */
    [self makeCollectionViewVisible];
    [self.collectionView reloadData];

}


#pragma mark - key and event handling

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

#pragma mark - data view vs video output handling

- (void)makeCollectionViewVisible
{
    [self setContentMinSize: NSMakeSize(604., f_min_window_height)];

    NSRect old_frame = [self frame];
    CGFloat newHeight = [self minSize].height;
    if (old_frame.size.height < newHeight) {
        NSRect new_frame = old_frame;
        new_frame.origin.y = old_frame.origin.y + old_frame.size.height - newHeight;
        new_frame.size.height = newHeight;

        [[self animator] setFrame:new_frame display:YES animate:YES];
    }

    [self.videoView setHidden:YES];
    [_collectionView setHidden:NO];
    if (self.nativeFullscreenMode && [self fullscreen]) {
        [self showControlsBar];
        [self.fspanel setNonActive];
    }

    [self makeFirstResponder:_collectionView];
    
  //  self.dataModel = [[VLCMainWindowDataModel alloc] init ] ;
    self.dummyData=[NSMutableArray arrayWithCapacity:0 ];
    self.collectionView.wantsLayer = YES;
    self.thumbinails = [NSMutableArray arrayWithCapacity:0];
    self.labels = [NSMutableArray arrayWithCapacity:0];
    self.years = [NSMutableArray arrayWithCapacity:0];
    [self prepareData];
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    self.collectionView.wantsLayer = YES;
    [self.collectionView registerClass:[VLCLibraryView class] forItemWithIdentifier:@"dummyViews"];
    
    NSCollectionViewFlowLayout *flowLayout = [[NSCollectionViewFlowLayout alloc]  init];
    flowLayout.itemSize = NSMakeSize(190,241);
    flowLayout.sectionInset = NSEdgeInsetsMake(10, 10, 10, 10);
    flowLayout.minimumInteritemSpacing = 20.0;
    flowLayout.minimumLineSpacing = 20.0;
    self.collectionView.collectionViewLayout = flowLayout;
    [self.collectionView reloadData];
}

- (void)prepareData {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *rootPath = @"/Users/vibhoothiiaanand/Desktop/dummyVideos";
    NSError *error = nil;
    NSArray *paths = [fileManager contentsOfDirectoryAtPath:rootPath error:&error];
    for(NSString *path in paths){
         NSString *videoPath = [rootPath stringByAppendingFormat:@"/%@",path];
        NSLog(@"Video Path:%@",videoPath);
        NSURL *url = [NSURL fileURLWithPath:videoPath];
    AVAsset *asset = [AVAsset assetWithURL:url];
    AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc]initWithAsset:asset];
    imageGenerator.appliesPreferredTrackTransform=YES;
    CMTime time = [asset duration];
    time.value = 0;
    float duration = CMTimeGetSeconds([asset duration]);
        CGImageRef imgRef = [imageGenerator copyCGImageAtTime:CMTimeMake(10, duration) actualTime:NULL error:nil];
        NSImage *thumbinail =[[NSImage alloc] initWithCGImage:imgRef size:NSSizeFromCGSize(CGSizeMake(100.0, 100.0))];
        if(thumbinail){
            self.dataModel = [[VLCLibraryItem alloc] init ] ;
            self.dataModel.thumbnail = thumbinail;
            self.dataModel.videoTitle= path;
            self.dataModel.year = @"2012";
            self.dataModel.length = @"303";
            [self.dummyData addObject:self.dataModel] ;
          
            
            /*
             [self.thumbinails  addObject:thumbinail];
             [self.labels       addObject:path];
             [self.years        addObject:@"2012"];
             NSLog(@"self thumbs %@",self.thumbinails);
            */
        //    NSLog(@"dummyData2:%@",dummyData2);
        }
  
    }
      NSLog(@"DataModel dummy %@",self.dummyData);
}

#pragma mark - NSCollectionViewDelegate

- (NSSet<NSIndexPath *> *)collectionView:(NSCollectionView *)collectionView shouldChangeItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths toHighlightState:(NSCollectionViewItemHighlightState)highlightState {
    return indexPaths;
}

#pragma mark - NSCollectionViewDataSource


- (void)collectionView:(NSCollectionView *)collectionView didSelectItemsAtIndexPaths:VLCLibraryViewItem
{
    NSLog(@"Video at:%@ is Selected",VLCLibraryViewItem);
   //Hide the CollectionView in favour of playing video when user clicks
    [self performSelector:@selector(makeCollectionViewHidden) withObject:self afterDelay:2.0 ];
    /*
     Insert code for playing Video using libVLCCore
    */
}

- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    
    return self.dummyData.count;
}
- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {

    /*
        Pass the metadata to the DataModel for assinging values to the views
        and return updated view
     */
    
    VLCLibraryView *item = [collectionView makeItemWithIdentifier:@"dummyViews" forIndexPath:indexPath];
    VLCLibraryItem *model =[VLCLibraryItem new];
    for(VLCLibraryItem  *subModel in self.dummyData)
    {
      //  self.dataModel = [[VLCMainWindowDataModel alloc] init ] ;
       // VLCMainWindowDataModel *model=[[VLCMainWindowDataModel alloc] init];
        model=subModel;
        NSLog(@"ModelTitle  %@",model.videoTitle);
        NSLog(@"SubModelTitle  %@",subModel.videoTitle);
        [item assignValueForDataModel:model];
    }
    NSLog(@"Model Thumbinal outside %@",model.videoTitle);
    return item;
    //NSLog(@"model Title:%@,modelThumb :%@",model.videoTitle,model.thumbnail);
    //[item assignValueForDataModel:model];
   
    /*
    model.videoTitle = [self.labels objectAtIndex:indexPath.item];
    model.thumbnail = [self.thumbinails objectAtIndex:indexPath.item];
    model.year = [self.years objectAtIndex:indexPath.item];
    [item assignValueForDataModel:model];
    */
    
}

- (NSInteger)numberOfSectionsInCollectionView:(NSCollectionView *)collectionView {
    return 1;
}

// Hides the collection view and makes the vout view in foreground
- (void)makeCollectionViewHidden
{
    [self setContentMinSize: NSMakeSize(604., f_min_video_height)];

    [_collectionView setHidden:YES];
    [self.videoView setHidden:NO];
    if (self.nativeFullscreenMode && [self fullscreen]) {
        [self hideControlsBar];
        [self.fspanel setActive];
    }

    if ([[self.videoView subviews] count] > 0)
        [self makeFirstResponder: [[self.videoView subviews] firstObject]];
}

- (void)changePlaylistState:(VLCPlaylistStateEvent)event
{
    // Beware, this code is really ugly

    msg_Dbg(getIntf(), "toggle playlist from state: removed collectionview %i, minimized view %i. Event %i", collectionViewRemoved, minimizedView, event);
    if (![self isVisible] && event == psUserMenuEvent) {
        [self makeKeyAndOrderFront: nil];
        return;
    }

    BOOL activeVideo = [[VLCMain sharedInstance] activeVideoPlayback];
    BOOL restored = NO;

    // ignore alt if triggered through main menu shortcut
    BOOL b_have_alt_key = ([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0;
    if (event == psUserMenuEvent)
        b_have_alt_key = NO;

    // eUserMenuEvent is now handled same as eUserEvent
    if(event == psUserMenuEvent)
        event = psUserEvent;

    if (!(self.nativeFullscreenMode && self.fullscreen) && !collectionViewRemoved && ((b_have_alt_key && activeVideo)
                                                                                    || (self.nonembedded && event == psUserEvent)
                                                                                    || (!activeVideo && event == psUserEvent)
                                                                                    || (minimizedView && event == psVideoStartedOrStoppedEvent))) {
        // for starting playback, window is resized through resized events
        // for stopping playback, resize through reset to previous frame
        [self hideCollectionView: event != psVideoStartedOrStoppedEvent];
        minimizedView = NO;
    } else {
        if (collectionViewRemoved) {
            if (!self.nonembedded || (event == psUserEvent && self.nonembedded))
                [self showCollectionView: event != psVideoStartedOrStoppedEvent];

            if (event != psUserEvent)
                minimizedView = YES;
            else
                minimizedView = NO;

            if (activeVideo)
                restored = YES;
        }

        if (!self.nonembedded) {
            if (([self.videoView isHidden] && activeVideo) || restored || (activeVideo && event != psUserEvent))
                [self makeCollectionViewHidden];
            else
                [self makeCollectionViewVisible];
        } else {
            [_collectionView setHidden: NO];
            [self.videoView setHidden: YES];
            [self showControlsBar];
        }
    }

    msg_Dbg(getIntf(), "toggle playlist to state: removed collectionview %i, minimized view %i", collectionViewRemoved, minimizedView);
}

- (void)hideCollectionView:(BOOL)resize
{
    if (resize) {
        NSRect winrect = [self frame];
        lastCollectionViewHeight = [_collectionView frame].size.height;
        winrect.size.height = winrect.size.height - lastCollectionViewHeight;
        winrect.origin.y = winrect.origin.y + lastCollectionViewHeight;
        [self setFrame:winrect display:YES animate:YES];
    }

    [self setContentMinSize: NSMakeSize(604., [self.controlsBar height])];
    [self setContentMaxSize: NSMakeSize(FLT_MAX, [self.controlsBar height])];

    collectionViewRemoved = YES;
}

- (void)showCollectionView:(BOOL)resize
{
    [self updateWindow];
    [self setContentMinSize:NSMakeSize(604., f_min_window_height)];
    [self setContentMaxSize: NSMakeSize(FLT_MAX, FLT_MAX)];

    if (resize) {
        NSRect winrect;
        winrect = [self frame];
        winrect.size.height = winrect.size.height + lastCollectionViewHeight;
        winrect.origin.y = winrect.origin.y - lastCollectionViewHeight;
        [self setFrame:winrect display:YES animate:YES];
    }

    collectionViewRemoved = NO;
}

#pragma mark -
#pragma mark overwritten default window functionality

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
            if(frameBeforePlayback.size.height > f_threshold_height || minimizedView) {

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
