# A large database of MIME types for 👑 Nim language
#
# (c) 2025 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/mimedb

import std/[os, macros, tables, options, json, strutils, locks]
import pkg/openparser/json

type
  MimeSource* = enum 
    ## The source of the MIME type information.
    mimeSourceNone = "none"
    mimeSourceApache = "apache"
    mimeSourceIana = "iana"
    mimeSourceNginx = "nginx"

  Mime* = ref object
    ## Represents a MIME type and its associated metadata.
    source: MimeSource
      # the source of this MIME type
    extensions: seq[string]
      # file extensions associated with this MIME type
    compressible: bool
      # whether this MIME type is compressible
    charset: Option[string]
      # default charset for this MIME type, if any

  ContentType* = string
    ## A string representing the MIME type, e.g., "text/html".

  MimeDatabaseStorage* = ref object
    extensions: TableRef[string, ContentType]
      # A table mapping file extensions to MIME types.
    types: TableRef[string, Mime]

  MimeDBException* = object of CatchableError
    ## Exception type for MIME database errors.

var MimeDB*: MimeDatabaseStorage
  ## A global variable that holds the MIME database.
  ## It contains mappings of MIME types to their metadata
  ## and file extensions to MIME types.
  ## Populated lazily on first use (see `ensureDatabase`): importing
  ## this module — and therefore starting any process that links it —
  ## parses nothing. The bundled 200KB JSON stays an untouched
  ## `const` until the first query.

var mimeDbLock: Lock
initLock(mimeDbLock)

const bundledMimeJson = staticRead("mimedb/db.json")
  ## Bundled database baked in at compile time (same file the
  ## `initDatabase` macro inlines). Untouched pages cost nothing
  ## thanks to demand paging.

proc initMimeDatabase*(data: sink string) =
  ## Initializes the MIME database from a JSON string at runtime.
  if MimeDB != nil: return
  # init the tables
  MimeDB = MimeDatabaseStorage(
    extensions: newTable[string, ContentType](),
    types: fromJson(data, TableRef[string, Mime])
  )
  for mimeType, mimeInfo in MimeDB.types:
    for ext in mimeInfo.extensions:
      MimeDB.extensions[ext] = mimeType

proc ensureDatabase*() =
  ## Parses the bundled database on first use (thread-safe,
  ## double-checked). Every query proc below calls this first, so
  ## callers never need an explicit init. Explicit `initDatabase()`
  ## / `initMimeDatabase(custom)` calls still work and win if they
  ## run first.
  if MimeDB != nil: return
  withLock(mimeDbLock):
    if MimeDB != nil: return
    initMimeDatabase(bundledMimeJson)

macro initDatabase*() =
  ## Eagerly loads the bundled MIME database (same data the lazy
  ## `ensureDatabase` parses on first query). Only needed when you
  ## want to pay the parse cost up front, e.g. before spawning
  ## worker threads on a backend without locks.
  const jsonData = staticRead(currentSourcePath().parentDir / "mimedb" / "db.json")
  result = newStmtList()
  add result, quote do:
    initMimeDatabase(`jsonData`)

proc normalizeExtension*(ext: string): string =
  ## Normalizes a file extension for database lookups.
  ## Strips whitespace, leading dots and lowercases the result,
  ## so `"html"`, `".html"` and `".HTML"` are all equivalent.
  ext.strip().strip(leading = true, trailing = false, chars = {'.'}).toLowerAscii()

proc isExtension*(ext: string): bool =
  ## Checks if the MIME database has an entry for the given file extension.
  ## Accepts extensions with or without a leading dot,
  ## e.g. both `"html"` and `".html"` work (case-insensitive).
  ensureDatabase()
  MimeDB.extensions.hasKey(ext.normalizeExtension)

proc hasMimeType*(mimeType: string): bool =
  ## Checks if the MIME database has an entry for a given MIME type.
  ensureDatabase()
  MimeDB.types.hasKey(mimeType)

proc getMimeType*(ext: string): Option[string] =
  ## Returns the MIME type for a given file extension, if it exists.
  ## Accepts extensions with or without a leading dot,
  ## e.g. both `"html"` and `".html"` work (case-insensitive).
  ensureDatabase()
  let key = ext.normalizeExtension
  if MimeDB.extensions.hasKey(key):
    return some(MimeDB.extensions[key])

proc getMimeInfo*(mimeType: string): Option[Mime] =
  ## Returns the `Mime` information for a given MIME type, if it exists.
  ensureDatabase()
  if MimeDB.types.hasKey(mimeType):
    return some(MimeDB.types[mimeType])

proc isCompressible*(mime: Option[Mime]): bool =
  ## Checks if the given MIME type is compressible.
  if mime.isSome:
    return mime.get().compressible
  false

proc needsNormalize(ext: string): bool {.inline.} =
  ## True when `normalizeExtension` would change `ext` (leading dot,
  ## surrounding ASCII whitespace/control, or any uppercase). The common
  ## already-clean value skips all copies.
  if ext.len == 0:
    return false
  if ext[0] == '.':
    return true
  for c in ext:
    if c <= ' ' or (c >= 'A' and c <= 'Z'):
      return true
  false

proc isCompressibleExt*(ext: string): bool =
  ## Compressibility for a file extension in one lookup pass, with no
  ## intermediate MIME-type string: `".HTML"` and `"html"` both work.
  ## Already-clean values allocate nothing.
  ensureDatabase()
  let key = if needsNormalize(ext): ext.normalizeExtension else: ext
  if MimeDB.extensions.hasKey(key):
    let mt = MimeDB.extensions[key]
    if MimeDB.types.hasKey(mt):
      return MimeDB.types[mt].compressible
  false

proc isCompressibleType*(mimeType: string): bool =
  ## Compressibility for a `Content-Type` header value: strips parameters
  ## (`text/html; charset=utf-8`) and matches case-insensitively. The common
  ## already-clean value allocates nothing; dirty values cost one small copy.
  ensureDatabase()
  var v = mimeType
  let sc = v.find(';')
  if sc >= 0:
    v = v[0 ..< sc]
  var a = 0
  var b = v.len
  while a < b and v[a] <= ' ':
    inc a
  while b > a and v[b - 1] <= ' ':
    dec b
  let key = if a == 0 and b == v.len: v else: v[a ..< b]
  if MimeDB.types.hasKey(key):
    return MimeDB.types[key].compressible
  var hasUpper = false
  for c in key:
    if c >= 'A' and c <= 'Z':
      hasUpper = true
      break
  if not hasUpper:
    return false
  let lower = key.toLowerAscii()
  MimeDB.types.hasKey(lower) and MimeDB.types[lower].compressible

proc getExtensions*(mime: Option[Mime]): Option[seq[string]] =
  ## Returns the file extensions associated with a given `Mime` type.
  if mime.get().extensions.len > 0:
    return some(mime.get().extensions)

proc hasExtension*(mime: Option[Mime], ext: string): bool =
  ## Checks if the given `Mime` type has the specified file extension.
  ## Accepts extensions with or without a leading dot,
  ## e.g. both `"zip"` and `".zip"` work (case-insensitive).
  if mime.isSome:
    return ext.normalizeExtension in mime.get().extensions

proc getSource*(mime: Option[Mime]): MimeSource =
  ## Returns the source of the given `Mime` type.
  mime.get().source
