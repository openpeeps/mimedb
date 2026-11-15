import unittest
import std/[os, strutils, options]

import mimedb

test "test mimedb functionality":
  assert getMimeType("html") == some("text/html")
  assert getMimeType("png") == some("image/png")
  assert getMimeType("unknownext") == none(string)

  let info1 = getMimeInfo("text/html")
  assert info1.isSome
  assert info1.getSource == mimeSourceIana
  assert info1.isCompressible == true

  let info2 = getMimeInfo("application/zip")
  assert info2.isSome
  assert info2.getSource == mimeSourceIana
  assert info2.isCompressible == false
  
  assert info2.getExtensions() == some(@["zip"])
  assert info2.hasExtension("zip") == true
  assert info2.isCompressible == false

  assert isCompressibleExt("html") == true
  assert isCompressibleExt(".HTML") == true
  assert isCompressibleExt("zip") == false
  assert isCompressibleExt("png") == false
  assert isCompressibleExt("unknownext") == false
  assert isCompressibleType("text/html") == true
  assert isCompressibleType("text/html; charset=utf-8") == true
  assert isCompressibleType("Text/HTML") == true
  assert isCompressibleType("image/png") == false
  assert isCompressibleType("application/zip") == false
  assert isCompressibleType("nope/nothing") == false

  assert isExtension("m4a")
  assert isExtension("mp4a")
  assert isExtension("m4b")

  let info3 = getMimeInfo("audio/mp4")
  assert info3.isSome
  assert info3.hasExtension("m4a")
