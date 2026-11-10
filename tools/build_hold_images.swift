#!/usr/bin/env swift
// Builds the hold pictures for the problem preview: one transparent sprite sheet per
// hold set (HoldImages-2016.png, HoldImages-2024.png) plus HoldImages.json.
//
// Source: the per-hold-set layer images in github.com/boardsesh/boardsesh
// (packages/web/public/images/moonboard, Apache-2.0), pinned to one commit. Each
// layer is a 650 × 1000 picture of one hold set's holds on a transparent background,
// already at their board positions. For 2016 the black holds come from the ".dark"
// layer, which boardsesh lightens so they show on a dark screen.
//
// What it does:
//   1. Finds each hold in each layer (a connected blob of opaque pixels). Layers are
//      kept apart because holds from different layers can touch.
//   2. Fits the 11 × 18 grid to the hold centres.
//   3. Gives each hold to its nearest grid position and copies it, alone, into that
//      position's square tile, centred on the grid point. Tiles sit in an 11 × 18
//      sheet: column A–K left to right, row 18 at the top.
//   4. Traces an outline around each hold, a few pixels out (HoldImages.json), so
//      the preview can outline the hold itself rather than circle its bolt hole.
//   5. Checks every hold used by a problem in Problems.json has a picture.
//
// Usage (from the repo root):  swift tools/build_hold_images.swift
// Never edit the outputs by hand; rerun this script and rebuild the app.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let sourceRepo = "boardsesh/boardsesh"
let sourceCommit = "03bbbc28fd9b6e856ea886d7c4cbc6c4d08a6257" // 2026-11-09
let sourceBase = "https://raw.githubusercontent.com/\(sourceRepo)/\(sourceCommit)/packages/web/public/images/moonboard/"
let layers: [(set: String, files: [String])] = [
    ("2016", ["moonboard2016/holdseta.png", "moonboard2016/holdsetb.dark.webp",
              "moonboard2016/originalschoolholds.png"]),
    ("2024", ["moonboard2024/holdsetd.png", "moonboard2024/holdsete.png", "moonboard2024/holdsetf.png",
              "moonboard2024/woodenholds.png", "moonboard2024/woodenholdsb.png", "moonboard2024/woodenholdsc.png"]),
]

let columns = 11
let rows = 18
let columnLetters = Array("ABCDEFGHIJK")
/// Pixels at least this opaque start a hold; fainter edge pixels join the nearest hold.
let alphaThreshold: UInt8 = 96
/// Blobs smaller than this (in pixels) are specks, not holds.
let minimumArea = 30

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let resources = root.appendingPathComponent("Moon Dance Watch App/Resources")

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

// MARK: - Pixels

struct Bitmap {
    let width: Int
    let height: Int
    /// Premultiplied RGBA, top row first.
    var pixels: [UInt8]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        pixels = [UInt8](repeating: 0, count: width * height * 4)
    }

    func alpha(_ x: Int, _ y: Int) -> UInt8 { pixels[(y * width + x) * 4 + 3] }

    mutating func draw(_ image: CGImage) {
        let (w, h) = (width, height)
        pixels.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                    bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
    }

    func write(to url: URL) {
        var copy = pixels
        let image = copy.withUnsafeMutableBytes { buffer -> CGImage in
            let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                    bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            return context.makeImage()!
        }
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { fail("couldn't write \(url.path)") }
    }
}

func loadImage(_ path: String) -> CGImage {
    let url = URL(string: sourceBase + path)!
    guard let data = try? Data(contentsOf: url) else { fail("couldn't download \(url)") }
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fail("couldn't decode \(path)") }
    return image
}

// MARK: - Holds

struct Blob {
    var pixels: [Int] = []
    var sumX = 0.0
    var sumY = 0.0
    var centre: (x: Double, y: Double) { (sumX / Double(pixels.count), sumY / Double(pixels.count)) }
}

/// Labels connected opaque blobs (8-connected). Returns a label per pixel (-1 = none).
func findBlobs(in bitmap: Bitmap) -> (labels: [Int], blobs: [Blob]) {
    let (w, h) = (bitmap.width, bitmap.height)
    var labels = [Int](repeating: -1, count: w * h)
    var blobs: [Blob] = []
    for start in 0..<(w * h) where labels[start] == -1 && bitmap.pixels[start * 4 + 3] >= alphaThreshold {
        var blob = Blob()
        var stack = [start]
        labels[start] = blobs.count
        while let index = stack.popLast() {
            let (x, y) = (index % w, index / w)
            blob.pixels.append(index)
            blob.sumX += Double(x) + 0.5
            blob.sumY += Double(y) + 0.5
            for dy in -1...1 {
                for dx in -1...1 {
                    let (nx, ny) = (x + dx, y + dy)
                    guard nx >= 0, ny >= 0, nx < w, ny < h else { continue }
                    let next = ny * w + nx
                    if labels[next] == -1 && bitmap.pixels[next * 4 + 3] >= alphaThreshold {
                        labels[next] = blobs.count
                        stack.append(next)
                    }
                }
            }
        }
        blobs.append(blob)
    }
    return (labels, blobs)
}

/// Grid: x = x0 + column × dx, y = y18 + (18 − row) × dy, in source pixels.
struct Grid {
    var x0 = 93.0, dx = 50.0, y18 = 90.0, dy = 50.0

    func cell(near point: (x: Double, y: Double)) -> (column: Int, row: Int, distance: Double)? {
        let column = Int(((point.x - x0) / dx).rounded())
        let fromTop = Int(((point.y - y18) / dy).rounded())
        let row = rows - fromTop
        guard (0..<columns).contains(column), (1...rows).contains(row) else { return nil }
        let centre = self.centre(column: column, row: row)
        let distance = hypot((point.x - centre.x) / dx, (point.y - centre.y) / dy)
        return (column, row, distance)
    }

    func centre(column: Int, row: Int) -> (x: Double, y: Double) {
        (x0 + Double(column) * dx, y18 + Double(rows - row) * dy)
    }

    /// Least-squares fit of the grid to blob centres, using their current cells.
    mutating func fit(_ blobs: [Blob]) {
        var xs: [(Double, Double)] = []
        var ys: [(Double, Double)] = []
        for blob in blobs {
            guard let cell = cell(near: blob.centre), cell.distance < 0.45 else { continue }
            xs.append((Double(cell.column), blob.centre.x))
            ys.append((Double(rows - cell.row), blob.centre.y))
        }
        func line(_ points: [(Double, Double)]) -> (Double, Double) {
            let n = Double(points.count)
            let mx = points.map(\.0).reduce(0, +) / n
            let my = points.map(\.1).reduce(0, +) / n
            let slope = points.map { ($0.0 - mx) * ($0.1 - my) }.reduce(0, +)
                / points.map { ($0.0 - mx) * ($0.0 - mx) }.reduce(0, +)
            return (my - slope * mx, slope)
        }
        (x0, dx) = line(xs)
        (y18, dy) = line(ys)
    }
}

func position(_ column: Int, _ row: Int) -> String { "\(columnLetters[column])\(row)" }

// MARK: - Outlines

/// Pixels at least this opaque count as the hold when tracing its outline.
let outlineAlpha: UInt8 = 64
/// How far outside the hold the outline runs, in source pixels.
let outlineGap = 5.0
/// Douglas–Peucker tolerance when simplifying outlines, in source pixels.
let outlineTolerance = 0.5

/// The outer edge of a set of pixels grown by `outlineGap`, as a closed loop of
/// points in source pixel coordinates (marching squares through pixel centres).
func traceOutline(_ pixels: [(Int, Int)]) -> [(x: Double, y: Double)] {
    let pad = Int(outlineGap.rounded(.up)) + 2
    let minX = pixels.map(\.0).min()! - pad, maxX = pixels.map(\.0).max()! + pad
    let minY = pixels.map(\.1).min()! - pad, maxY = pixels.map(\.1).max()! + pad
    let (w, h) = (maxX - minX + 1, maxY - minY + 1)

    // Grow the hold by a disc of radius outlineGap.
    var mask = [Bool](repeating: false, count: w * h)
    let reach = Int(outlineGap)
    for (px, py) in pixels {
        for dy in -reach...reach {
            for dx in -reach...reach where Double(dx * dx + dy * dy) <= outlineGap * outlineGap {
                mask[(py - minY + dy) * w + (px - minX + dx)] = true
            }
        }
    }
    func inside(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < w && y < h && mask[y * w + x] }

    // Marching squares on pixel centres. Points are edge midpoints, kept in doubled
    // coordinates so they're exact integers; each is shared by exactly two segments.
    struct Key: Hashable { let x: Int, y: Int }
    var links: [Key: [Key]] = [:]
    func link(_ a: Key, _ b: Key) {
        links[a, default: []].append(b)
        links[b, default: []].append(a)
    }
    for y in -1..<h {
        for x in -1..<w {
            let a = inside(x, y), b = inside(x + 1, y), c = inside(x + 1, y + 1), d = inside(x, y + 1)
            let top = Key(x: 2 * x + 1, y: 2 * y), right = Key(x: 2 * x + 2, y: 2 * y + 1)
            let bottom = Key(x: 2 * x + 1, y: 2 * y + 2), left = Key(x: 2 * x, y: 2 * y + 1)
            if a == c && b == d && a != b {
                // Saddle: cut off the two outside corners.
                if a { link(top, right); link(bottom, left) } else { link(top, left); link(right, bottom) }
                continue
            }
            var mixed: [Key] = []
            if a != b { mixed.append(top) }
            if b != c { mixed.append(right) }
            if c != d { mixed.append(bottom) }
            if d != a { mixed.append(left) }
            if mixed.count == 2 { link(mixed[0], mixed[1]) }
        }
    }

    // Walk the loops and keep the biggest (the outside edge, not any holes).
    var visited: Set<Key> = []
    var best: [Key] = []
    var bestArea = 0.0
    for start in links.keys where !visited.contains(start) {
        var loop = [start]
        visited.insert(start)
        var previous = start
        var current = links[start]![0]
        while current != start {
            loop.append(current)
            visited.insert(current)
            let next = links[current]!.first { $0 != previous } ?? start
            previous = current
            current = next
        }
        var area = 0.0
        for i in loop.indices {
            let (p, q) = (loop[i], loop[(i + 1) % loop.count])
            area += Double(p.x * q.y - q.x * p.y)
        }
        if abs(area) > bestArea {
            bestArea = abs(area)
            best = loop
        }
    }

    // Doubled grid coordinates → source pixels (pixel centres sit at +0.5).
    let points = best.map { (x: Double($0.x) / 2 + Double(minX) + 0.5, y: Double($0.y) / 2 + Double(minY) + 0.5) }
    return simplify(points + [points[0]], tolerance: outlineTolerance).dropLast()
}

/// Douglas–Peucker: drops points within `tolerance` of the line through their neighbours.
func simplify(_ points: [(x: Double, y: Double)], tolerance: Double) -> [(x: Double, y: Double)] {
    guard points.count > 2 else { return points }
    let (first, last) = (points[0], points[points.count - 1])
    var farthest = 0
    var distance = 0.0
    for i in 1..<(points.count - 1) {
        let p = points[i]
        let length = hypot(last.x - first.x, last.y - first.y)
        let d = length == 0
            ? hypot(p.x - first.x, p.y - first.y)
            : abs((last.x - first.x) * (first.y - p.y) - (first.x - p.x) * (last.y - first.y)) / length
        if d > distance { (farthest, distance) = (i, d) }
    }
    if distance <= tolerance { return [first, last] }
    let left = simplify(Array(points[...farthest]), tolerance: tolerance)
    let right = simplify(Array(points[farthest...]), tolerance: tolerance)
    return left.dropLast() + right
}

// MARK: - Build

let problemsURL = resources.appendingPathComponent("Problems.json")
guard let problemsData = try? Data(contentsOf: problemsURL),
      let problemsJSON = try? JSONSerialization.jsonObject(with: problemsData) as? [String: Any],
      let problems = problemsJSON["problems"] as? [[String: Any]] else { fail("couldn't read Problems.json") }

var manifest: [String: Any] = ["source": "github.com/\(sourceRepo)@\(String(sourceCommit.prefix(7)))"]
var sets: [String: Any] = [:]

/// One hold: its pixels (index into the layer) and the layer they come from.
struct Hold {
    let layer: Int
    let pixels: [Int]
    let centre: (x: Double, y: Double)
}

for (set, files) in layers {
    print("\(set): \(files.count) layers")
    // Holds are found layer by layer: holds from different layers can touch.
    var bitmaps: [Bitmap] = []
    var holds: [Hold] = []
    for file in files {
        let image = loadImage(file)
        var bitmap = Bitmap(width: image.width, height: image.height)
        bitmap.draw(image)
        if let first = bitmaps.first, first.width != bitmap.width || first.height != bitmap.height {
            fail("\(file) is a different size")
        }
        let (w, h) = (bitmap.width, bitmap.height)
        var (labels, blobs) = findBlobs(in: bitmap)
        let kept = Set(blobs.indices.filter { blobs[$0].pixels.count >= minimumArea })
        let centres = blobs.map(\.centre) // before edge pixels are added
        // Faint edge pixels join the hold next to them (three passes of growing outwards).
        for _ in 0..<3 {
            var grown = labels
            for index in 0..<(w * h) where labels[index] == -1 && bitmap.pixels[index * 4 + 3] > 0 {
                let (x, y) = (index % w, index / w)
                search: for dy in -1...1 {
                    for dx in -1...1 {
                        let (nx, ny) = (x + dx, y + dy)
                        guard nx >= 0, ny >= 0, nx < w, ny < h else { continue }
                        let label = labels[ny * w + nx]
                        if label >= 0, kept.contains(label) {
                            grown[index] = label
                            blobs[label].pixels.append(index)
                            break search
                        }
                    }
                }
            }
            labels = grown
        }
        let layerHolds = kept.sorted().map { Hold(layer: bitmaps.count, pixels: blobs[$0].pixels, centre: centres[$0]) }
        print("  \(file): \(layerHolds.count) holds")
        holds += layerHolds
        bitmaps.append(bitmap)
    }
    let width = bitmaps[0].width

    var grid = Grid()
    let asBlobs = holds.map { hold -> Blob in
        var blob = Blob()
        blob.pixels = [0]
        blob.sumX = hold.centre.x
        blob.sumY = hold.centre.y
        return blob
    }
    for _ in 0..<3 { grid.fit(asBlobs) }
    print(String(format: "  grid: A at x %.1f, %.2f px per column; row 18 at y %.1f, %.2f px per row",
                 grid.x0, grid.dx, grid.y18, grid.dy))

    // Give each hold to its nearest grid position.
    var cellOfHold: [Int: Int] = [:] // hold → cell index (column * rows + row - 1)
    var holdsInCell: [Int: [Int]] = [:]
    for (index, hold) in holds.enumerated() {
        guard let cell = grid.cell(near: hold.centre), cell.distance < 0.6 else {
            print(String(format: "  warning: hold at (%.0f, %.0f) is far from any grid point; skipped",
                         hold.centre.x, hold.centre.y))
            continue
        }
        let key = cell.column * rows + cell.row - 1
        cellOfHold[index] = key
        holdsInCell[key, default: []].append(index)
    }
    for (key, inCell) in holdsInCell where inCell.filter({ holds[$0].pixels.count > 300 }).count > 1 {
        print("  warning: \(position(key / rows, key % rows + 1)) has \(inCell.count) holds")
    }

    // Each hold's outline: its edge pushed out by `outlineGap` pixels, traced and
    // simplified, in cells from its grid point. The preview strokes it in the
    // hold's role colour, hugging the hold whatever its shape or offset.
    let cellPixels = (grid.dx + grid.dy) / 2
    var outlines: [String: [Double]] = [:]
    for (key, inCell) in holdsInCell {
        let centre = grid.centre(column: key / rows, row: key % rows + 1)
        var solid: [(Int, Int)] = []
        for index in inCell {
            let alpha = bitmaps[holds[index].layer].pixels
            for pixel in holds[index].pixels where alpha[pixel * 4 + 3] >= outlineAlpha {
                solid.append((pixel % width, pixel / width))
            }
        }
        let loop = traceOutline(solid)
        guard loop.count >= 6 else { fail("\(position(key / rows, key % rows + 1)): outline too small") }
        func rounded(_ value: Double) -> Double { (value * 1000).rounded() / 1000 }
        outlines[position(key / rows, key % rows + 1)] = loop.flatMap { point in
            [rounded((point.x - centre.x) / cellPixels), rounded((point.y - centre.y) / cellPixels)]
        }
    }
    let pointCounts = outlines.values.map { $0.count / 2 }
    print("  outlines: \(pointCounts.min()!)–\(pointCounts.max()!) points each")

    // Tile size: big enough for the hold reaching furthest from its grid point.
    var reach = 0.0
    for (index, key) in cellOfHold {
        let centre = grid.centre(column: key / rows, row: key % rows + 1)
        for pixel in holds[index].pixels {
            let (x, y) = (Double(pixel % width) + 0.5, Double(pixel / width) + 0.5)
            reach = max(reach, abs(x - centre.x), abs(y - centre.y))
        }
    }
    let half = Int(reach.rounded(.up)) + 2
    let tile = half * 2
    print("  \(holdsInCell.count) positions; furthest pixel \(Int(reach)) px from its grid point; tile \(tile) px")

    // Copy each hold into its tile, layers in order (premultiplied "source over").
    var sheet = Bitmap(width: columns * tile, height: rows * tile)
    for (index, hold) in holds.enumerated() {
        guard let key = cellOfHold[index] else { continue }
        let (column, row) = (key / rows, key % rows + 1)
        let centre = grid.centre(column: column, row: row)
        let source = bitmaps[hold.layer].pixels
        for pixel in hold.pixels {
            let tx = pixel % width - Int(centre.x.rounded()) + half
            let ty = pixel / width - Int(centre.y.rounded()) + half
            guard (0..<tile).contains(tx), (0..<tile).contains(ty) else { continue }
            let out = (((rows - row) * tile + ty) * sheet.width + column * tile + tx) * 4
            let inverse = 255 - Int(source[pixel * 4 + 3])
            for channel in 0..<4 {
                let below = Int(sheet.pixels[out + channel])
                sheet.pixels[out + channel] = UInt8(min(255, Int(source[pixel * 4 + channel]) + below * inverse / 255))
            }
        }
    }

    let output = resources.appendingPathComponent("HoldImages-\(set).png")
    sheet.write(to: output)
    print("  wrote \(output.lastPathComponent) (\(sheet.width) × \(sheet.height))")

    let present = Set(holdsInCell.keys.map { position($0 / rows, $0 % rows + 1) })
    var missing: [String: Int] = [:]
    for problem in problems where problem["holdSet"] as? String == set {
        for hold in problem["holds"] as? [[String: Any]] ?? [] {
            if let spot = hold["position"] as? String, !present.contains(spot) { missing[spot, default: 0] += 1 }
        }
    }
    if !missing.isEmpty {
        fail("\(set): problems use positions with no hold picture: \(missing.sorted { $0.key < $1.key })")
    }
    print("  every hold used by a \(set) problem has a picture")

    sets[set] = [
        "tile": tile,
        "cell": (grid.dx + grid.dy) / 2,
        // Position → outline as [x0, y0, x1, y1, …], in cells from the grid point
        // (y down).
        "outlines": outlines,
    ]
}

manifest["sets"] = sets
let manifestURL = resources.appendingPathComponent("HoldImages.json")
let json = try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys])
try json.write(to: manifestURL)
print("wrote \(manifestURL.lastPathComponent)")
