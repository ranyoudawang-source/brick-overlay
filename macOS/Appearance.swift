import Foundation

struct Appearance: Codable, Equatable {
    var width = 850
    var height = 652
    var opacity = 22
    var mode = 0 // 0: bricks; 1: random bricks; 2: document bands
    var brickWidth = 150
    var brickHeight = 48
    var minimumHeight = 24
    var maximumHeight = 96
    var randomWidth = false
    var minimumWidth = 80
    var maximumWidth = 240
    var bands = 4
    var seed: UInt32 = 731
    var colors = ["F26F6C", "F5C84C", "68B995", "58B6D3", "967BC5"]

    static func clamp(_ n: Int, _ lo: Int, _ hi: Int) -> Int { min(hi, max(lo, n)) }
    static func hex(_ value: String) -> String? {
        let s = value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "").uppercased()
        guard s.count == 6, s.allSatisfy({ "0123456789ABCDEF".contains($0) }) else { return nil }
        return s
    }
    mutating func normalize() {
        width = Self.clamp(width, 100, 6000); height = Self.clamp(height, 48, 4000)
        opacity = Self.clamp(opacity, 5, 65); mode = Self.clamp(mode, 0, 2)
        brickWidth = Self.clamp(brickWidth, 24, 1200); brickHeight = Self.clamp(brickHeight, 8, 1000)
        minimumHeight = Self.clamp(minimumHeight, 8, 1000)
        maximumHeight = Self.clamp(maximumHeight, minimumHeight, 1000)
        minimumWidth = Self.clamp(minimumWidth, 24, 1200)
        maximumWidth = Self.clamp(maximumWidth, minimumWidth, 1200)
        bands = Self.clamp(bands, 2, 16)
        colors = Array(colors.compactMap(Self.hex).prefix(12))
        if colors.isEmpty { colors = ["58B6D3"] }
    }
    enum CodingKeys: String, CodingKey { case width, height, opacity, mode, brickWidth, brickHeight, minimumHeight, maximumHeight, randomWidth, minimumWidth, maximumWidth, bands, seed, colors }
    init() {}
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        width = try c.decodeIfPresent(Int.self, forKey: .width) ?? width
        height = try c.decodeIfPresent(Int.self, forKey: .height) ?? height
        opacity = try c.decodeIfPresent(Int.self, forKey: .opacity) ?? opacity
        mode = try c.decodeIfPresent(Int.self, forKey: .mode) ?? mode
        brickWidth = try c.decodeIfPresent(Int.self, forKey: .brickWidth) ?? brickWidth
        brickHeight = try c.decodeIfPresent(Int.self, forKey: .brickHeight) ?? brickHeight
        minimumHeight = try c.decodeIfPresent(Int.self, forKey: .minimumHeight) ?? minimumHeight
        maximumHeight = try c.decodeIfPresent(Int.self, forKey: .maximumHeight) ?? maximumHeight
        randomWidth = try c.decodeIfPresent(Bool.self, forKey: .randomWidth) ?? randomWidth
        minimumWidth = try c.decodeIfPresent(Int.self, forKey: .minimumWidth) ?? minimumWidth
        maximumWidth = try c.decodeIfPresent(Int.self, forKey: .maximumWidth) ?? maximumWidth
        bands = try c.decodeIfPresent(Int.self, forKey: .bands) ?? bands
        seed = try c.decodeIfPresent(UInt32.self, forKey: .seed) ?? seed
        colors = try c.decodeIfPresent([String].self, forKey: .colors) ?? colors
        normalize()
    }
}

struct Tile: Equatable {
    var x: Int; var y: Int; var width: Int; var height: Int; var color: Int
}

enum Layout {
    static func hash(_ seed: UInt32, _ col: Int, _ row: Int) -> UInt32 {
        var x = seed &+ UInt32(col) &* 374761393 &+ UInt32(row) &* 668265263
        x = (x ^ (x >> 13)) &* 1274126177
        return x ^ (x >> 16)
    }
    static func tiles(_ value: Appearance) -> [Tile] {
        var a = value; a.normalize()
        var result: [Tile] = []
        func append(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: Int) {
            let left = max(0,x), top = max(0,y), right = min(a.width,x+w), bottom = min(a.height,y+h)
            if right > left && bottom > top {
                result.append(Tile(x: left, y: top, width: right-left, height: bottom-top, color: color % a.colors.count))
            }
        }
        if a.mode == 2 {
            let gap = min(3, (a.height - a.bands) / (a.bands - 1))
            let available = a.height - (a.bands - 1) * gap
            for i in 0..<a.bands {
                let top = i * available / a.bands + i * gap
                let end = (i+1) * available / a.bands + i * gap
                append(0,top,a.width,end-top,i)
            }
        } else if a.mode == 1 && a.randomWidth {
            // Shared row heights tile the surface without overlaps or empty pockets.
            // Separate hash streams keep width and height choices independent.
            var row = 0, y = 0
            while y < a.height {
                let h = a.minimumHeight + Int(hash(a.seed,0,row) % UInt32(a.maximumHeight-a.minimumHeight+1))
                var col = 0, x = 0
                while x < a.width {
                    let w = a.minimumWidth + Int(hash(a.seed ^ 0x9E3779B9,col,row) % UInt32(a.maximumWidth-a.minimumWidth+1))
                    append(x,y,w,h,col+row*2)
                    x += w + 3; col += 1
                }
                y += h + 3; row += 1
            }
        } else if a.mode == 1 {
            var col = 0, x = 0
            while x < a.width {
                var row = 0, y = 0
                while y < a.height {
                    let h = a.minimumHeight + Int(hash(a.seed,col,row) % UInt32(a.maximumHeight-a.minimumHeight+1))
                    append(x,y,a.brickWidth,h,col+row*2)
                    y += h + 3; row += 1
                }
                x += a.brickWidth + 3; col += 1
            }
        } else {
            var row = 0, y = 0
            while y < a.height {
                var col = 0, x = row % 2 == 0 ? 0 : -a.brickWidth / 2
                while x < a.width {
                    append(x,y,a.brickWidth,a.brickHeight,col+row*2)
                    x += a.brickWidth + 3; col += 1
                }
                y += a.brickHeight + 3; row += 1
            }
        }
        return result
    }
}

struct SavedState: Codable {
    var current = Appearance()
    var startup: Appearance?
    var presets: [String: Appearance] = [:]
}
