<p align="center">
  A large database of MIME types<br>for 👑 Nim language 
</p>

<p align="center">
  <code>nimble install mimedb</code>
</p>

<p align="center">
  <a href="https://openpeeps.github.io/mimedb/">API reference</a><br>
  <img src="https://github.com/openpeeps/mimedb/workflows/test/badge.svg" alt="Github Actions">  <img src="https://github.com/openpeeps/mimedb/workflows/docs/badge.svg" alt="Github Actions">
</p>

> [!NOTE]  
> This is a large database of mime types and information about them. It consists of a single, public JSON file and does not include any logic, allowing it to remain as un-opinionated as possible with an API.

## 😍 Key Features
- Large database of MIME types
- Simple API to get MIME type information
- Lightweight and easy to use

## Examples
The database loads automatically on `import`, no setup needed.

```nim
import mimedb
import std/options

# Extension to MIME type.
# Extensions work with or without a leading dot (case-insensitive)
assert getMimeType("html") == some("text/html")
assert getMimeType(".html") == some("text/html")
assert getMimeType("PNG") == some("image/png")
assert getMimeType(".png") == some("image/png")
assert getMimeType("unknownext") == none(string)

# Check if an extension or MIME type exists
assert isExtension("html")
assert isExtension(".html")
assert hasMimeType("text/html")
```

```nim
import mimedb
import std/options

# Get full info for a MIME type
let info = getMimeInfo("text/html")
assert info.isSome
assert info.getSource() == mimeSourceIana
assert info.isCompressible() == true
assert info.getExtensions() == some(@["html", "htm", "shtml"])
assert info.hasExtension("html")
assert info.hasExtension(".html") # leading dot also works
```

```nim
import mimedb
import std/options

let zip = getMimeInfo("application/zip")
assert zip.isSome
assert zip.getSource() == mimeSourceIana
assert zip.isCompressible() == false
assert zip.getExtensions() == some(@["zip"])
assert zip.hasExtension(".zip")

let audio = getMimeInfo("audio/mp4")
assert audio.hasExtension("m4a")
assert audio.hasExtension(".m4a")
```


This package is using the [mime-db](https://github.com/jshttp/mime-db) database.

### ❤ Contributions & Support
- 🐛 Found a bug? [Create a new Issue](https://github.com/openpeeps/mimedb/issues)
- 👋 Wanna help? [Fork it!](https://github.com/openpeeps/mimedb/fork)

### 🎩 License
MIT license. [Made by Humans from OpenPeeps](https://github.com/openpeeps).<br>
Copyright OpenPeeps & Contributors &mdash; All rights reserved.
