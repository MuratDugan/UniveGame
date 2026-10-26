import Foundation

/// External disks as their own drive letters in a Windows environment (`D:` → /Volumes/STRIX). Wine shows the
/// whole Mac as `Z:`, and programs that check free space at a drive's root (HoYoPlay, installers) then see the
/// Mac's internal disk instead of the external one the game is going to. A letter of its own fixes that, and
/// makes the disk easy to find in Windows folder pickers.
enum ExternalDrives {
    /// Mounted volumes worth a letter: local, browsable, not the Mac's own disk.
    static func mountedVolumes() -> [URL] {
        let keys: [URLResourceKey] = [.volumeIsRootFileSystemKey, .volumeIsLocalKey, .volumeIsBrowsableKey, .volumeIsInternalKey]
        let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        return volumes.filter { url in
            guard url.path.hasPrefix("/Volumes/"), let v = try? url.resourceValues(forKeys: Set(keys)) else { return false }
            return v.volumeIsRootFileSystem != true && v.volumeIsLocal == true && v.volumeIsBrowsable == true && v.volumeIsInternal != true
        }
    }

    /// Links each of `volumes` into the environment's `dosdevices` under the first free letter from D:, unless a
    /// letter already points to it. Existing letters (C:, Z:, ones Wine or the player made) are never changed.
    /// Returns the letters added.
    @discardableResult
    static func link(_ volumes: [URL], into dosdevices: URL) -> [String] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: dosdevices.path) else { return [] }
        let entries = (try? fm.contentsOfDirectory(atPath: dosdevices.path)) ?? []
        var used = Set(entries.map { $0.lowercased() })
        let mapped = Set(entries.compactMap { try? fm.destinationOfSymbolicLink(atPath: dosdevices.appendingPathComponent($0).path) }
            .map { URL(fileURLWithPath: $0).standardizedFileURL.path })
        var added: [String] = []
        for volume in volumes where !mapped.contains(volume.standardizedFileURL.path) {
            guard let letter = "defghijklmnopqrstuvwxy".map({ "\($0):" }).first(where: { !used.contains($0) }) else { break }
            guard (try? fm.createSymbolicLink(atPath: dosdevices.appendingPathComponent(letter).path,
                                              withDestinationPath: volume.standardizedFileURL.path)) != nil else { continue }
            used.insert(letter)
            added.append(letter)
        }
        return added
    }

    static func link(into bottle: URL) {
        link(mountedVolumes(), into: bottle.appendingPathComponent("dosdevices", isDirectory: true))
    }
}
