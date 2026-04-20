local lib = require "tests/lib"
local plume = require"plume-data/engine/init"
plume.debugForcedRoot = ""
local tests = lib.loadTests("tests/plume")
lib.executeTests(tests, plume)
lib.analyzeResults(tests)

lib.generateReport(tests, "tests/report.html")