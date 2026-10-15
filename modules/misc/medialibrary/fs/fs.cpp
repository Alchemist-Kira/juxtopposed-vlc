/*****************************************************************************
 * util.cpp: Media library utils
 *****************************************************************************
 * Copyright (C) 2018 VLC authors, VideoLAN and VideoLabs
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <algorithm>
#include <vlc_services_discovery.h>
#ifdef _WIN32
# include <vlc_fs.h>
# include <sys/stat.h>
#endif
#include <medialibrary/IDeviceLister.h>
#include <medialibrary/filesystem/IDevice.h>
#include <medialibrary/IMediaLibrary.h>

#include "device.h"
#include "directory.h"
#include "util.h"
#include "fs.h"

namespace vlc {
  namespace medialibrary {

using namespace ::medialibrary;

#ifdef _WIN32
// A UNC share need not have a drive letter or appear in WNet's connected-drive
// list. Resolve explicitly selected shares through the Windows file API instead
// of depending on LAN discovery. The share root is also a stable device ID, so
// saved entry points can be resolved after a restart.
static std::shared_ptr<IDevice> uncDevice(const std::string& mrl)
{
    try
    {
        vlc::url url{ mrl };
        if (!url.psz_protocol || strcasecmp(url.psz_protocol, "file") || !url.psz_host ||
            !*url.psz_host || !strcasecmp(url.psz_host, "localhost") ||
            url.psz_username || url.psz_password || url.i_port ||
            !url.psz_path || url.psz_path[0] != '/' || !url.psz_path[1])
            return nullptr;

        const std::string path = url.psz_path;
        auto end = path.find('/', 1);
        std::string share = path.substr(0, end);
        if (share == "/." || share == "/..")
            return nullptr;
        share += '/';
        url.psz_path = share.data();
        url.psz_option = nullptr;
        auto root = vlc::wrap_cptr(vlc_uri_compose(&url));
        if (!root)
            return nullptr;
        auto localPath = vlc::wrap_cptr(vlc_uri2path(root.get()));
        struct stat st;
        if (!localPath || vlc_stat(localPath.get(), &st) || !S_ISDIR(st.st_mode))
            return nullptr;

        std::string uuid = root.get();
        std::transform(uuid.begin(), uuid.end(), uuid.begin(), [](unsigned char c) {
            return c >= 'A' && c <= 'Z' ? c + ('a' - 'A') : c;
        });
        auto device = std::make_shared<SDDevice>("unc:" + uuid, "file://", true, true);
        device->addMountpoint(root.get());
        return device;
    }
    catch (const vlc::url::invalid&)
    {
        return nullptr;
    }
}
#endif

SDFileSystemFactory::SDFileSystemFactory(vlc_object_t *parent,
                                         const std::string &scheme)
    : m_parent(parent)
    , m_scheme(scheme)
    , m_callbacks( nullptr )
    , m_parser(parent, {
        .types = VLC_PREPARSER_TYPE_PARSE,
        .max_parser_threads = 1,
        .max_thumbnailer_threads = 0,
        .timeout = VLC_TICK_FROM_SEC(15),
#if !defined(HAVE_VLC_EXTERNAL_PREPARSER)
        .external_process = false,
#else
        .external_process = true,
#endif
    })
{
    m_isNetwork = strncasecmp( m_scheme.c_str(), "file://",
                               m_scheme.length() ) != 0;
}

bool SDFileSystemFactory::initialize(const IMediaLibrary* ml)
{
    m_deviceLister = ml->deviceLister(m_scheme);
    return m_deviceLister != nullptr;
}

std::shared_ptr<fs::IDirectory>
SDFileSystemFactory::createDirectory(const std::string &mrl)
{
    return std::make_shared<SDDirectory>(mrl, *this);
}

std::shared_ptr<fs::IFile>
SDFileSystemFactory::createFile(const std::string& mrl)
{
    auto dir = createDirectory(utils::directory(mrl));
    assert(dir != nullptr);
    return dir->file(mrl);
}

std::shared_ptr<IDevice>
SDFileSystemFactory::createDevice(const std::string &uuid)
{
#ifdef _WIN32
    if (m_scheme == "file://" && uuid.compare(0, 4, "unc:") == 0)
        return uncDevice(uuid.substr(4));
#endif
    vlc::threads::mutex_locker locker(m_mutex);

    assert( isStarted() == true );

    return deviceByUuid(uuid);
}

std::shared_ptr<IDevice>
SDFileSystemFactory::createDeviceFromMrl(const std::string &mrl)
{
#ifdef _WIN32
    if (m_scheme == "file://")
        if (auto device = uncDevice(mrl))
            return device;
#endif
    vlc::threads::mutex_locker locker(m_mutex);

    assert( isStarted() == true );
    return deviceByMrl(mrl);
}

void
SDFileSystemFactory::refreshDevices()
{
    m_deviceLister->refresh();
}

bool
SDFileSystemFactory::isMrlSupported(const std::string &path) const
{
    return !path.compare(0, m_scheme.length(), m_scheme);
}

bool
SDFileSystemFactory::isNetworkFileSystem() const
{
    return m_isNetwork;
}

const std::string &
SDFileSystemFactory::scheme() const
{
    return m_scheme;
}

bool
SDFileSystemFactory::start(IFileSystemFactoryCb *callbacks)
{
    assert( isStarted() == false );
    m_callbacks = callbacks;
    return m_deviceLister->start( this );
}

void
SDFileSystemFactory::stop()
{
    assert( isStarted() == true );
    m_deviceLister->stop();
    m_callbacks = nullptr;
}

libvlc_int_t *
SDFileSystemFactory::libvlc() const
{
    return vlc_object_instance(m_parent);
}

LazyPreparser&
SDFileSystemFactory::getPreparser()
{
    vlc::threads::mutex_locker lock(m_mutex);
    return m_parser;
}

void SDFileSystemFactory::onDeviceMounted(const std::string& uuid,
                                          const std::string& mountpoint,
                                          bool removable)
{
    if ( strncasecmp( mountpoint.c_str(), m_scheme.c_str(), m_scheme.length() ) != 0 )
        return;

    std::shared_ptr<fs::IDevice> device;
    {
        vlc::threads::mutex_locker lock(m_mutex);
        device = deviceByUuid(uuid);
        if (device == nullptr)
        {
            device = std::make_shared<SDDevice>(uuid, m_scheme,
                                                removable, isNetworkFileSystem() );
            m_devices.push_back(device);
        }
        device->addMountpoint(mountpoint);
    }
    m_callbacks->onDeviceMounted( *device, mountpoint );
}

void vlc::medialibrary::SDFileSystemFactory::onDeviceUnmounted(const std::string& uuid,
                                                               const std::string& mountpoint)
{
    if ( strncasecmp( mountpoint.c_str(), m_scheme.c_str(), m_scheme.length() ) != 0 )
        return;

    std::shared_ptr<fs::IDevice> device;
    {
        vlc::threads::mutex_locker lock(m_mutex);
        device = deviceByUuid(uuid);
    }
    if ( device == nullptr )
    {
        assert( !"Unknown device was unmounted" );
        return;
    }
    device->removeMountpoint(mountpoint);
    m_callbacks->onDeviceUnmounted(*device, mountpoint);
}

bool SDFileSystemFactory::waitForDevice(const std::string& mrl,
                                        uint32_t timeout) const
{
#ifdef _WIN32
    if (m_scheme == "file://" && uncDevice(mrl))
        return true;
#endif
    auto deadline = vlc_tick_now() + VLC_TICK_FROM_MS(timeout);
    vlc::threads::mutex_locker lock{ m_mutex };
    while ( deviceByMrl(mrl) == nullptr )
    {
        if ( m_cond.timedwait(m_mutex, deadline) != 0 )
            return false;
    }
    return true;
}

std::shared_ptr<IDevice> SDFileSystemFactory::deviceByUuid(const std::string& uuid)
{
    auto it = std::find_if( begin( m_devices ), end( m_devices ),
                            [&uuid]( const std::shared_ptr<fs::IDevice>& d ) {
        return strcasecmp( d->uuid().c_str(), uuid.c_str() ) == 0;
    });
    if ( it == end( m_devices ) )
        return nullptr;
    return *it;
}

bool SDFileSystemFactory::isStarted() const
{
    return m_callbacks != nullptr;
}

std::shared_ptr<IDevice> SDFileSystemFactory::deviceByMrl(const std::string& mrl) const
{
    std::shared_ptr<fs::IDevice> res;
    std::string mountpoint;
    for ( const auto& d : m_devices )
    {
        auto match = d->matchesMountpoint( mrl );
        if ( std::get<0>( match ) == false )
            continue;
        auto newMountpoint = std::get<1>( match );
        if ( res == nullptr || newMountpoint.length() > mountpoint.length() )
        {
            res = d;
            mountpoint = std::move( newMountpoint );
        }
    }
    return res;
}

  } /* namespace medialibrary */
} /* namespace vlc */
