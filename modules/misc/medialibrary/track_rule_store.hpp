// SPDX-License-Identifier: LGPL-2.1-or-later
#pragma once
#include <string>
#include <vector>

namespace vlc::medialibrary {

class TrackRuleStore
{
public:
    explicit TrackRuleStore(std::string directory) : m_directory(std::move(directory)) {}
    bool read(const std::string& folderMrl, int type, std::string& definition) const;
    bool write(const std::string& folderMrl, int type, const std::string& definition) const;
    bool resolve(const std::string& definition, const std::string& mediaName,
                 bool& applies, std::vector<std::string>& paths) const;
    std::string location(const std::string& folderMrl, int type) const;
private:
    std::string scope(const std::string& folderMrl) const;
    std::string m_directory;
};

}
