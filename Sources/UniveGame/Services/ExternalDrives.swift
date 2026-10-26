import Foundation

/// External disks as their own drive letters in every Windows environment (`E:` → /Volumes/STRIX). Wine shows the
/// whole Mac as `Z:`, and programs that check free space at a drive's root (HoYoPlay, installers) then see the
/// Mac's internal disk instead of the external one the game is going to. A letter of its own fixes that, and
/// makes the disk easy to find in Windows folder pickers.
///
/// A disk keeps its letter by its volume id, so it gets the same one after a rename or on another port, and the
/// letter stays while the disk is unplugged: games installed there keep their path. Links into /Volumes are
/// UniveGame's to manage; every other letter (C:, Z:, anything Wine or the player made) is left alone.
enum ExternalDrives {
    struct Disk: Identifiable, Equatable {
        /// The volume's UUID, or its path when it has none.
        let id: String
        let name: String
        let url: URL
        let capacity: Int64?
        let available: Int64?
        /// "APFS", "ExFAT", "NTFS"…
        let format: String?
        let readOnly: Bool
    }

    /// The player's choice for a disk: its letter (`"e:"`), or nil to keep it out of Windows. `path` is where it was
    /// last mounted, so the letter still points there while it's unplugged.
    struct Assignment: Codable, Equatable {
        var letter: String?
        var path: String
    }

    static let letters = "defghijklmnopqrstuvwxy".map { "\($0):" }

    /// Mounted disks worth a letter: local, browsable, not the Mac's own disk.
    static func mountedDisks() -> [Disk] {
        let keys: [URLResourceKey] = [.volumeIsRootFileSystemKey, .volumeIsLocalKey, .volumeIsBrowsableKey, .volumeIsInternalKey,
                                      .volumeUUIDStringKey, .volumeLocalizedNameKey, .volumeTotalCapacityKey,
                                      .volumeAvailableCapacityKey, .volumeLocalizedFormatDescriptionKey, .volumeIsReadOnlyKey,
                                      .volumeTypeNameKey]
        let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        return volumes.compactMap { url -> Disk? in
            guard url.path.hasPrefix("/Volumes/"), let v = try? url.resourceValues(forKeys: Set(keys)),
                  v.volumeIsRootFileSystem != true, v.volumeIsLocal == true, v.volumeIsBrowsable == true, v.volumeIsInternal != true
            else { return nil }
            return Disk(id: v.volumeUUIDString ?? url.path, name: v.volumeLocalizedName ?? url.lastPathComponent, url: url,
                        capacity: v.volumeTotalCapacity.map(Int64.init), available: v.volumeAvailableCapacity.map(Int64.init),
                        format: formatName(v.volumeTypeName) ?? v.volumeLocalizedFormatDescription,
                        readOnly: v.volumeIsReadOnly == true)
        }
    }

    /// "exFAT", "NTFS"… from the file system's type name ("exfat", "ntfs").
    static func formatName(_ type: String?) -> String? {
        guard let type = type?.lowercased() else { return nil }
        let names = ["exfat": "exFAT", "msdos": "FAT32", "ntfs": "NTFS", "apfs": "APFS", "hfs": "Mac OS Extended"]
        return names[type] ?? type
    }

    /// `saved` brought up to date with `disks`: known disks keep their letter (or stay hidden) and get their current
    /// path; new ones get the first letter that is neither `reserved` nor another disk's.
    static func assign(_ disks: [Disk], saved: [String: Assignment], reserved: Set<String>) -> [String: Assignment] {
        var result = saved
        for disk in disks { result[disk.id, default: Assignment(letter: nil, path: disk.url.path)].path = disk.url.path }
        for disk in disks where saved[disk.id] == nil {
            let taken = reserved.union(result.values.compactMap(\.letter))
            result[disk.id]?.letter = letters.first { !taken.contains($0) }
        }
        return result
    }

    /// Letters wanted in every environment: letter → mount path.
    static func wanted(_ assignments: [String: Assignment]) -> [String: String] {
        var map: [String: String] = [:]
        for a in assignments.values { if let letter = a.letter { map[letter] = a.path } }
        return map
    }

    /// Letters in `dosdevices` that aren't UniveGame's (they don't point into /Volumes): never handed out.
    static func foreignLetters(in dosdevices: URL) -> Set<String> {
        let fm = FileManager.default
        let entries = (try? fm.contentsOfDirectory(atPath: dosdevices.path)) ?? []
        return Set(entries.map { $0.lowercased() }.filter { name in
            guard name.count == 2, name.hasSuffix(":") else { return false }
            let target = try? fm.destinationOfSymbolicLink(atPath: dosdevices.appendingPathComponent(name).path)
            return !(target?.hasPrefix("/Volumes/") ?? false)
        })
    }

    /// Makes `dosdevices` match `wanted`: our links (into /Volumes) that aren't wanted go, wanted ones are made or
    /// repointed. A letter held by something else is left as it is.
    static func apply(_ wanted: [String: String], to dosdevices: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: dosdevices.path) else { return }
        let foreign = foreignLetters(in: dosdevices)
        for name in (try? fm.contentsOfDirectory(atPath: dosdevices.path)) ?? [] where name.count == 2 && name.hasSuffix(":") {
            let link = dosdevices.appendingPathComponent(name)
            guard let target = try? fm.destinationOfSymbolicLink(atPath: link.path), target.hasPrefix("/Volumes/"),
                  wanted[name.lowercased()] != target else { continue }
            try? fm.removeItem(at: link)
        }
        for (letter, path) in wanted where !foreign.contains(letter) {
            let link = dosdevices.appendingPathComponent(letter)
            if (try? fm.destinationOfSymbolicLink(atPath: link.path)) == path { continue }
            try? fm.createSymbolicLink(atPath: link.path, withDestinationPath: path)
        }
    }
}
