local lib = require "tests/lib"
local plume = require"plume-data/engine/init"
require"debug-tools/core" (plume)
plume.debugForcedRoot = ""
local tests = lib.loadTests("tests/plume")
lib.loadTests("tests/plume/std", tests)
lib.loadTests("tests/cli", tests)
lib.executeTests(tests, plume)
lib.analyzeResults(tests)

lib.generateReport(tests, "tests/report.html")
lib.generateTextReport(tests, "tests/report.txt")
lib.updateReadmeBadge(tests.stats, "readme.md")