# Package

version       = "0.0.1"
author        = "jiyinyiyong"
description   = "Script runner for Cirru"
license       = "MIT"
srcDir        = "src"
bin           = @["cr"]
binDir        = "out/"



# Dependencies

requires "nim >= 0.20.0"
requires "cirru-parser >= 0.0.3"
