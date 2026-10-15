// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick

QtObject {
    function decode(segment) {
        try { return decodeURIComponent(segment) } catch (error) { return segment }
    }
    function split(value) {
        let path = value.toString().replace(/\\/g, "/")
        let prefix = "file://"
        let encoded = false
        const url = /^([a-z][a-z0-9+.-]*):\/\/([^/]*)(.*)$/i.exec(path)
        if (url) {
            prefix = url[1].toLowerCase() + "://" + url[2].toLowerCase()
            path = url[3].split(/[?#]/)[0]
            encoded = true
        } else if (path.startsWith("//")) {
            const slash = path.indexOf("/", 2)
            if (slash < 0) return null
            prefix += path.slice(2, slash).toLowerCase()
            path = path.slice(slash)
        } else if (!path.startsWith("/") && !/^[a-z]:\//i.test(path)) {
            return null
        }
        const parts = []
        for (const part of path.split("/")) {
            const name = encoded ? decode(part) : part
            if (!name || name === ".") continue
            if (name === "..") {
                const anchor = prefix.startsWith("file://") && prefix !== "file://" || /^[a-z]:$/i.test(parts[0] || "") ? 1 : 0
                if (parts.length > anchor) parts.pop()
                continue
            }
            parts.push(/^[a-z]:$/i.test(name) && !parts.length ? name : encodeURIComponent(name))
        }
        return {prefix: prefix, parts: parts, windows: prefix.startsWith("file://") && prefix !== "file://" || /^[a-z]:$/i.test(parts[0] || "")}
    }
    function location(value) {
        const path = split(value)
        return path ? path.prefix + "/" + path.parts.join("/") : value.toString()
    }
    function trail(value, roots) {
        if (!value) return []
        const path = split(value)
        if (!path) return [value.toString()]
        // Keep a drive or network share as the first navigable location.
        let start = path.windows && path.parts.length ? 1 : 0
        const same = (a, b) => path.windows ? a.toLowerCase() === b.toLowerCase() : a === b
        for (const root of roots) {
            const candidate = split(root)
            if (candidate && same(candidate.prefix, path.prefix) && candidate.parts.length <= path.parts.length
                    && candidate.parts.every((part, index) => same(part, path.parts[index])))
                start = Math.max(start, candidate.parts.length)
        }
        const result = []
        for (let length = start; length <= path.parts.length; ++length)
            result.push(path.prefix + "/" + path.parts.slice(0, length).join("/"))
        return result
    }
}
