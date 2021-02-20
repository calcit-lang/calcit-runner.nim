
# calcit-runner is used for both evaling and compiling to js
# configs collected in order to expose to whole program

let commandLineVersion* = "0.2.63"

# dirty states controlling js backend
var jsMode* = false
var jsEmitPath* = "js-out"
var mjsMode* = false # TODO not working correctly now

var irMode* = false
var irEmitPath* = "js-out"
