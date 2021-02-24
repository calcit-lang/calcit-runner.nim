
# calcit-runner is used for both evaling and compiling to js
# configs collected in order to expose to whole program

let commandLineVersion* = "0.2.69"

# dirty states controlling js backend
var jsMode* = false
var mjsMode* = false # TODO not working correctly now

var irMode* = false

var codeEmitPath* = "js-out"