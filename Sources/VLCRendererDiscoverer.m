/*****************************************************************************
 * VLCRendererDiscoverer.m
 *****************************************************************************
 * Copyright © 2018 VLC authors, VideoLAN
 * Copyright © 2018 Videolabs
 *
 * Authors: Soomin Lee<bubu@mikan.io>
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#import "VLCRendererDiscoverer.h"
#import "VLCLibrary.h"
#import "VLCEventManager.h"
#import "VLCRendererItem+Init.h"

@interface VLCRendererDiscoverer()
{
    libvlc_renderer_discoverer_t *_rendererDiscoverer;
}
@end

#pragma mark - LibVLC event callbacks

static void HandleRendererDiscovererItemAdded(const libvlc_event_t *event, void *self)
{
    @autoreleasepool {
        [[VLCEventManager sharedManager] callOnMainThreadObject:(__bridge id)(self)
                                                     withMethod:@selector(itemAdded:)
                                           withArgumentAsObject:[[VLCRendererItem alloc] initWithCItem:
                                                                 event->u.renderer_discoverer_item_added.item]];
    }
}

static void HandleRendererDiscovererItemDeleted(const libvlc_event_t *event, void *self)
{
    @autoreleasepool {
        [[VLCEventManager sharedManager] callOnMainThreadObject:(__bridge id)(self)
                                                     withMethod:@selector(itemDeleted:)
                                           withArgumentAsObject:[[VLCRendererItem alloc] initWithCItem:
                                                                  event->u.renderer_discoverer_item_deleted.item]];
    }
}

#pragma mark - VLCRendererDiscovererDescription

@implementation VLCRendererDiscovererDescription

- (instancetype)initWithName:(NSString *)name longName:(NSString *)longName
{
    self = [super init];
    if (self) {
        NSAssert(!name, @"VLCRendererDiscovererDescription: name is NULL");
        _name = name;

        NSAssert(!longName, @"VLCRendererDiscovererDescription: longName is NULL");
        _longName = longName;
    }
    return self;
}

@end

#pragma mark - VLCRendererDiscoverer

@implementation VLCRendererDiscoverer

- (instancetype)initWithName:(NSString *)name
{
    self = [super init];
    if (self) {
        NSAssert(!name, @"VLCRendererDiscoverer: name is NULL");
        _name = name;
        _rendererDiscoverer = libvlc_renderer_discoverer_new([VLCLibrary sharedLibrary].instance, [name UTF8String]);

        if (!_rendererDiscoverer) {
            NSAssert(_rendererDiscoverer, @"Failed to create renderer with name %@", name);
            return nil;
        }

        libvlc_event_manager_t *p_em = libvlc_renderer_discoverer_event_manager(_rendererDiscoverer);

        if (p_em) {
            libvlc_event_attach(p_em, libvlc_RendererDiscovererItemAdded,
                                HandleRendererDiscovererItemAdded, (__bridge void *)(self));
            libvlc_event_attach(p_em, libvlc_RendererDiscovererItemDeleted,
                                HandleRendererDiscovererItemDeleted, (__bridge void *)(self));
        }

    }
    return self;
}

- (BOOL)start
{
    return libvlc_renderer_discoverer_start(_rendererDiscoverer) == 0;
}

- (void)stop
{
    libvlc_renderer_discoverer_stop(_rendererDiscoverer);
}

- (void)dealloc
{
    libvlc_event_manager_t *p_em = libvlc_renderer_discoverer_event_manager(_rendererDiscoverer);

    if (p_em) {
        libvlc_event_detach(p_em, libvlc_RendererDiscovererItemAdded,
                            HandleRendererDiscovererItemAdded, (__bridge void *)(self));
        libvlc_event_detach(p_em, libvlc_RendererDiscovererItemDeleted,
                            HandleRendererDiscovererItemDeleted, (__bridge void *)(self));
    }

    if (_rendererDiscoverer) {
        libvlc_renderer_discoverer_release(_rendererDiscoverer);
    }
}

+ (NSArray<VLCRendererDiscovererDescription *> *)list
{
    size_t i_nb_services = 0;
    libvlc_rd_description_t **pp_services = NULL;

    i_nb_services = libvlc_renderer_discoverer_list_get([VLCLibrary sharedLibrary].instance, &pp_services);

    if (i_nb_services == 0) {
        return NULL;
    }

    NSMutableArray *list = [[NSMutableArray alloc] init];

    for (size_t i = 0; i < i_nb_services; ++i) {
        [list addObject:[[VLCRendererDiscovererDescription alloc] initWithName:[NSString stringWithUTF8String:pp_services[i]->psz_name]
                                                                      longName:[NSString stringWithUTF8String:pp_services[i]->psz_longname]]];
    }

    if (pp_services) {
        libvlc_renderer_discoverer_list_release(pp_services, i_nb_services);
    }
    return [list copy];
}

#pragma mark - Handling libvlc event callbacks

- (void)itemAdded:(VLCRendererItem *)item
{
    [_delegate rendererDiscovererItemAdded:self item:item];
}

- (void)itemDeleted:(VLCRendererItem *)item
{
    [_delegate rendererDiscovererItemDeleted:self item:item];
}

@end
