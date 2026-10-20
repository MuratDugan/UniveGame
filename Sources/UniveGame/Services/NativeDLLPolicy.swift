import Foundation

/// Games often ship Microsoft's DirectX helper DLLs next to their executable (D3DCompiler_43.dll, d3dx9_*.dll…).
/// Windows always uses those copies; Wine replaces them with its own builtins, which are incomplete for some of
/// them (its HLSL compiler fails or crawls on complex shaders). Prefer the game's own copies, as Windows would.
/// Nothing is added to the game; it just loads the files it shipped.
enum NativeDLLPolicy {
    /// Families where the game's copy should win. C/C++ runtimes are left to Wine: its builtins are mature.
    static let prefixes = ["d3dcompiler_", "d3dx9_", "d3dx10", "d3dx11_", "xaudio2_", "x3daudio1_", "xactengine", "xapofx1_"]

    /// DLL names (lowercased, no extension) found directly in `folders` that belong to those families.
    static func shippedHelpers(in folders: [URL]) -> [String] {
        var names = Set<String>()
        for folder in folders {
            let files = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
            for file in files where file.lowercased().hasSuffix(".dll") {
                let name = String(file.dropLast(4)).lowercased()
                if prefixes.contains(where: { name.hasPrefix($0) }) { names.insert(name) }
            }
        }
        return names.sorted()
    }

    /// A `WINEDLLOVERRIDES` entry ("a,b=n,b": native first, Wine's builtin as fallback), or nothing.
    static func overrides(for folders: [URL]) -> [String] {
        let names = shippedHelpers(in: folders)
        return names.isEmpty ? [] : [names.joined(separator: ",") + "=n,b"]
    }
}
