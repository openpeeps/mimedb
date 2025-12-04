# A large database of MIME types for 👑 Nim language
#
# (c) 2025 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/mimedb

import std/[os, macros, tables, options, json, strutils, sequtils]
import pkg/jsony

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

proc initMimeDatabase*(data: sink string) =
  ## Initializes the MIME database from a JSON string at runtime.
  if MimeDB != nil: raise newException(MimeDBException, "MIME database has already been initialized.")
  # init the tables
  MimeDB = MimeDatabaseStorage(
    extensions: newTable[string, ContentType](),
    types: fromJson(data, TableRef[string, Mime])
  )
  for mimeType, mimeInfo in MimeDB.types:
    for ext in mimeInfo.extensions:
      MimeDB.extensions[ext] = mimeType

macro initDatabase*() =
  ## Loads the MIME database from a JSON file at runtime.
  ## This macro reads the JSON file at compile-time. At runtime,
  ## is parsed and populates the `MimeDatabase` and `MimeDatabaseExtensions` tables.
  const jsonData = staticRead(currentSourcePath().parentDir / "mimedb" / "db.json")
  result = newStmtList()
  add result, quote do:
    initMimeDatabase(`jsonData`)

proc isExtension*(ext: string): bool =
  ## Checks if the MIME database has an entry for the given file extension.
  MimeDB.extensions.hasKey(ext)

proc hasMimeType*(mimeType: string): bool =
  ## Checks if the MIME database has an entry for the given MIME type.
  MimeDB.types.hasKey(mimeType)

proc getMimeType*(ext: string): Option[string] =
  ## Returns the MIME type for a given file extension, if it exists.
  if MimeDB.extensions.hasKey(ext):
    return some(MimeDB.extensions[ext])

proc getMimeInfo*(mimeType: string): Option[Mime] =
  ## Returns the `Mime` information for a given MIME type, if it exists.
  if MimeDB.types.hasKey(mimeType):
    return some(MimeDB.types[mimeType])

proc isCompressible*(mime: Option[Mime]): bool =
  ## Checks if the given MIME type is compressible.
  if mime.isSome:
    return mime.get().compressible

proc getExtensions*(mime: Option[Mime]): Option[seq[string]] =
  ## Returns the file extensions associated with a given `Mime` type.
  if mime.get().extensions.len > 0:
    return some(mime.get().extensions)

proc hasExtension*(mime: Option[Mime], ext: string): bool =
  ## Checks if the given `Mime` type has the specified file extension.
  if mime.isSome:
    return ext in mime.get().extensions

proc getSource*(mime: Option[Mime]): MimeSource =
  ## Returns the source of the given `Mime` type.
  mime.get().source

# Using this as a package dependency, load the MIME database at runtime
initDatabase()
