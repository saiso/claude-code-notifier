// claude-code-notifier のアイコンを生成する。
// 実行: swift generate-notifier-icon.swift {ベル PNG のパス} {出力先 PNG}
// 出力: 1024x1024 の PNG。
//   - 背景: Claude Crail (#C15F3C)、角丸 squircle
//   - ベル: Claude Cream (#f0eee6)
// ベル形状は Heroicons (MIT License, Copyright (c) 2020 Refactoring UI Inc.) の bell-solid を mask として使用する。
// 事前に rsvg-convert でラスタライズした PNG を渡す想定。

import Foundation
import AppKit

let args = CommandLine.arguments
guard args.count >= 3 else {
	FileHandle.standardError.write("使い方: swift generate-notifier-icon.swift {bell.png} {output.png}\n".data(using: .utf8)!)
	exit(1)
}

let bellPath = args[1]
let output = args[2]

let canvas = CGSize(width: 1024, height: 1024)
let bgColor = NSColor(red: 0xC1/255.0, green: 0x5F/255.0, blue: 0x3C/255.0, alpha: 1.0)
let bellColor = NSColor(red: 0xF0/255.0, green: 0xEE/255.0, blue: 0xE6/255.0, alpha: 1.0)

guard FileManager.default.fileExists(atPath: bellPath) else {
	FileHandle.standardError.write("ベル PNG が見つからない: \(bellPath)\n".data(using: .utf8)!)
	exit(1)
}

guard let bellImage = NSImage(contentsOfFile: bellPath),
      let bellCGImage = bellImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
	FileHandle.standardError.write("ベル画像を読み込めない: \(bellPath)\n".data(using: .utf8)!)
	exit(1)
}

let image = NSImage(size: canvas)
image.lockFocus()

// 背景（角丸 squircle）
bgColor.setFill()
let cornerRadius: CGFloat = 220
NSBezierPath(
	roundedRect: NSRect(x: 0, y: 0, width: canvas.width, height: canvas.height),
	xRadius: cornerRadius,
	yRadius: cornerRadius
).fill()

// ベルを mask として cream color で塗る
let bellSize: CGFloat = 600
let bellRect = NSRect(
	x: (canvas.width - bellSize) / 2,
	y: (canvas.height - bellSize) / 2 - 20,
	width: bellSize,
	height: bellSize
)
if let ctx = NSGraphicsContext.current?.cgContext {
	ctx.saveGState()
	ctx.clip(to: bellRect, mask: bellCGImage)
	ctx.setFillColor(bellColor.cgColor)
	ctx.fill(bellRect)
	ctx.restoreGState()
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
	FileHandle.standardError.write("PNG 変換に失敗\n".data(using: .utf8)!)
	exit(1)
}

try png.write(to: URL(fileURLWithPath: output))
print("生成: \(output)")
