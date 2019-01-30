/*****************************************************************************
 * CustomAspectRatio.h: Panel for making custom aspect ratio
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

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface VLCCustomAspectRatio : NSWindowController
@property (readwrite, weak) IBOutlet NSTextField *customAspectRatioLabel;
@property (readwrite, weak) IBOutlet NSButton *okButton;
@property (readwrite, weak) IBOutlet NSButton *cancelButton;
@property (nonatomic) int aspectRatioValue;

/**
 * Shows the panel as a modal dialog with window as its owner.
 * \param window Parent window for the dialog.
 * \param handler Completion block.
 */
typedef void(^VLCCustomAspectRatioHandler)(NSInteger returnCode, int64_t returnTime);
- (void)runModalForWindow:(NSWindow *)window completionHandler:(VLCCustomAspectRatioHandler)handler;


@end

NS_ASSUME_NONNULL_END
