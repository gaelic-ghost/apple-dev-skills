# SwiftPM Command Matrix

## Inspection and shape

- `swift package describe`
- `swift package dump-package`
- `swift package show-dependencies`

## Build, test, and run

- `swift build`
- `swift test`
- `swift run <target>`

## Manifest and dependency work

- `swift package add-dependency <url>`
- `swift package update`
- `swift package resolve`
- `swift package reset`

## Plugins and tools

- `swift package plugin --list`
- `swift package plugin --allow-writing-to-package-directory <plugin>`
- `swift package clean`

## Toolchain checks

- `swift --version`
- `swift package --help`
- `xcrun --find swift` when Apple toolchain location matters
