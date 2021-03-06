

public struct WallpaperSettings: PostboxCoding, Equatable {
    public var blur: Bool
    public var motion: Bool
    public var colors: [UInt32]
    public var intensity: Int32?
    public var rotation: Int32?
    
    public init(blur: Bool = false, motion: Bool = false, colors: [UInt32] = [], intensity: Int32? = nil, rotation: Int32? = nil) {
        self.blur = blur
        self.motion = motion
        self.colors = colors
        self.intensity = intensity
        self.rotation = rotation
    }
    
    public init(decoder: PostboxDecoder) {
        self.blur = decoder.decodeInt32ForKey("b", orElse: 0) != 0
        self.motion = decoder.decodeInt32ForKey("m", orElse: 0) != 0
        if let topColor = decoder.decodeOptionalInt32ForKey("c").flatMap(UInt32.init(bitPattern:)) {
            var colors: [UInt32] = [topColor]
            if let bottomColor = decoder.decodeOptionalInt32ForKey("bc").flatMap(UInt32.init(bitPattern:)) {
                colors.append(bottomColor)
            }
            self.colors = colors
        } else {
            self.colors = decoder.decodeInt32ArrayForKey("colors").map(UInt32.init(bitPattern:))
        }

        self.intensity = decoder.decodeOptionalInt32ForKey("i")
        self.rotation = decoder.decodeOptionalInt32ForKey("r")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.blur ? 1 : 0, forKey: "b")
        encoder.encodeInt32(self.motion ? 1 : 0, forKey: "m")
        encoder.encodeInt32Array(self.colors.map(Int32.init(bitPattern:)), forKey: "colors")
        if let intensity = self.intensity {
            encoder.encodeInt32(intensity, forKey: "i")
        } else {
            encoder.encodeNil(forKey: "i")
        }
        if let rotation = self.rotation {
            encoder.encodeInt32(rotation, forKey: "r")
        } else {
            encoder.encodeNil(forKey: "r")
        }
    }
    
    public static func ==(lhs: WallpaperSettings, rhs: WallpaperSettings) -> Bool {
        if lhs.blur != rhs.blur {
            return false
        }
        if lhs.motion != rhs.motion {
            return false
        }
        if lhs.colors != rhs.colors {
            return false
        }
        if lhs.intensity != rhs.intensity {
            return false
        }
        if lhs.rotation != rhs.rotation {
            return false
        }
        return true
    }
}

public enum TelegramWallpaper: OrderedItemListEntryContents, Equatable {
    case builtin(WallpaperSettings)
    case color(UInt32)
    case gradient(Int64?, [UInt32], WallpaperSettings)
    case image([TelegramMediaImageRepresentation], WallpaperSettings)
    case file(id: Int64, accessHash: Int64, isCreator: Bool, isDefault: Bool, isPattern: Bool, isDark: Bool, slug: String, file: TelegramMediaFile, settings: WallpaperSettings)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("v", orElse: 0) {
        case 0:
            let settings = decoder.decodeObjectForKey("settings", decoder: { WallpaperSettings(decoder: $0) }) as? WallpaperSettings ?? WallpaperSettings()
            self = .builtin(settings)
        case 1:
            self = .color(UInt32(bitPattern: decoder.decodeInt32ForKey("c", orElse: 0)))
        case 2:
            let settings = decoder.decodeObjectForKey("settings", decoder: { WallpaperSettings(decoder: $0) }) as? WallpaperSettings ?? WallpaperSettings()
            self = .image(decoder.decodeObjectArrayWithDecoderForKey("i"), settings)
        case 3:
            let settings = decoder.decodeObjectForKey("settings", decoder: { WallpaperSettings(decoder: $0) }) as? WallpaperSettings ?? WallpaperSettings()
            if let file = decoder.decodeObjectForKey("file", decoder: { TelegramMediaFile(decoder: $0) }) as? TelegramMediaFile {
                self = .file(id: decoder.decodeInt64ForKey("id", orElse: 0), accessHash: decoder.decodeInt64ForKey("accessHash", orElse: 0), isCreator: decoder.decodeInt32ForKey("isCreator", orElse: 0) != 0, isDefault: decoder.decodeInt32ForKey("isDefault", orElse: 0) != 0, isPattern: decoder.decodeInt32ForKey("isPattern", orElse: 0) != 0, isDark: decoder.decodeInt32ForKey("isDark", orElse: 0) != 0, slug: decoder.decodeStringForKey("slug", orElse: ""), file: file, settings: settings)
            } else {
                self = .color(0xffffff)
            }
        case 4:
            let settings = decoder.decodeObjectForKey("settings", decoder: { WallpaperSettings(decoder: $0) }) as? WallpaperSettings ?? WallpaperSettings()

            var colors: [UInt32] = []

            if let topColor = decoder.decodeOptionalInt32ForKey("c1").flatMap(UInt32.init(bitPattern:)) {
                colors.append(topColor)
                if let bottomColor = decoder.decodeOptionalInt32ForKey("c2").flatMap(UInt32.init(bitPattern:)) {
                    colors.append(bottomColor)
                }
            } else {
                colors = decoder.decodeInt32ArrayForKey("colors").map(UInt32.init(bitPattern:))
            }

            self = .gradient(decoder.decodeOptionalInt64ForKey("id"), colors, settings)
        default:
            assertionFailure()
            self = .color(0xffffff)
        }
    }
    
    public var hasWallpaper: Bool {
        switch self {
            case .color:
                return false
            default:
                return true
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .builtin(settings):
                encoder.encodeInt32(0, forKey: "v")
                encoder.encodeObject(settings, forKey: "settings")
            case let .color(color):
                encoder.encodeInt32(1, forKey: "v")
                encoder.encodeInt32(Int32(bitPattern: color), forKey: "c")
            case let .gradient(id, colors, settings):
                encoder.encodeInt32(4, forKey: "v")
                if let id = id {
                    encoder.encodeInt64(id, forKey: "id")
                } else {
                    encoder.encodeNil(forKey: "id")
                }
                encoder.encodeInt32Array(colors.map(Int32.init(bitPattern:)), forKey: "colors")
                encoder.encodeObject(settings, forKey: "settings")
            case let .image(representations, settings):
                encoder.encodeInt32(2, forKey: "v")
                encoder.encodeObjectArray(representations, forKey: "i")
                encoder.encodeObject(settings, forKey: "settings")
            case let .file(id, accessHash, isCreator, isDefault, isPattern, isDark, slug, file, settings):
                encoder.encodeInt32(3, forKey: "v")
                encoder.encodeInt64(id, forKey: "id")
                encoder.encodeInt64(accessHash, forKey: "accessHash")
                encoder.encodeInt32(isCreator ? 1 : 0, forKey: "isCreator")
                encoder.encodeInt32(isDefault ? 1 : 0, forKey: "isDefault")
                encoder.encodeInt32(isPattern ? 1 : 0, forKey: "isPattern")
                encoder.encodeInt32(isDark ? 1 : 0, forKey: "isDark")
                encoder.encodeString(slug, forKey: "slug")
                encoder.encodeObject(file, forKey: "file")
                encoder.encodeObject(settings, forKey: "settings")
        }
    }
    
    public static func ==(lhs: TelegramWallpaper, rhs: TelegramWallpaper) -> Bool {
        switch lhs {
            case let .builtin(settings):
                if case .builtin(settings) = rhs {
                    return true
                } else {
                    return false
                }
            case let .color(color):
                if case .color(color) = rhs {
                    return true
                } else {
                    return false
                }
            case let .gradient(id, colors, settings):
                if case .gradient(id, colors, settings) = rhs {
                    return true
                } else {
                    return false
                }
            case let .image(representations, settings):
                if case .image(representations, settings) = rhs {
                    return true
                } else {
                    return false
            }
            case let .file(lhsId, _, lhsIsCreator, lhsIsDefault, lhsIsPattern, lhsIsDark, lhsSlug, lhsFile, lhsSettings):
                if case let .file(rhsId, _, rhsIsCreator, rhsIsDefault, rhsIsPattern, rhsIsDark, rhsSlug, rhsFile, rhsSettings) = rhs, lhsId == rhsId, lhsIsCreator == rhsIsCreator, lhsIsDefault == rhsIsDefault, lhsIsPattern == rhsIsPattern, lhsIsDark == rhsIsDark, lhsSlug == rhsSlug, lhsFile.id == rhsFile.id, lhsSettings == rhsSettings {
                    return true
                } else {
                    return false
                }
        }
    }
    
    public func isBasicallyEqual(to wallpaper: TelegramWallpaper) -> Bool {
        switch self {
            case .builtin:
                if case .builtin = wallpaper {
                    return true
                } else {
                    return false
                }
            case let .color(color):
                if case .color(color) = wallpaper {
                    return true
                } else {
                    return false
                }
            case let .gradient(_, colors, _):
                if case .gradient(_, colors, _) = wallpaper {
                    return true
                } else {
                    return false
                }
            case let .image(representations, _):
                if case .image(representations, _) = wallpaper {
                    return true
                } else {
                    return false
                }
            case let .file(_, _, _, _, _, _, lhsSlug, _, lhsSettings):
                if case let .file(_, _, _, _, _, _, rhsSlug, _, rhsSettings) = wallpaper, lhsSlug == rhsSlug, lhsSettings.colors == rhsSettings.colors && lhsSettings.intensity == rhsSettings.intensity {
                    return true
                } else {
                    return false
                }
        }
    }
    
    public var settings: WallpaperSettings? {
        switch self {
            case let .builtin(settings), let .gradient(_, _, settings), let .image(_, settings), let .file(_, _, _, _, _, _, _, _, settings):
                return settings
            default:
                return nil
        }
    }
    
    public func withUpdatedSettings(_ settings: WallpaperSettings) -> TelegramWallpaper {
        switch self {
            case .builtin:
                return .builtin(settings)
            case .color:
                return self
            case let .gradient(id, colors, _):
                return .gradient(id, colors, settings)
            case let .image(representations, _):
                return .image(representations, settings)
            case let .file(id, accessHash, isCreator, isDefault, isPattern, isDark, slug, file, _):
                return .file(id: id, accessHash: accessHash, isCreator: isCreator, isDefault: isDefault, isPattern: isPattern, isDark: isDark, slug: slug, file: file, settings: settings)
        }
    }
}
