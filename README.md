

This project has been written in Rust, check [calcit_runner.rs](https://github.com/calcit-lang/calcit_runner.rs).
----

Rust as a stronger type system, which offers a more solid base for building a language.

-----

[Migrated] Calcit Runner
----

> An interpreter runtime for Calcit snapshot file.

- Home http://calcit-lang.org/
- APIs http://apis.calcit-lang.org/

Running [Calcit Editor](https://github.com/Cirru/calcit-editor#compact-output) with `compact=true caclcit-editor` enables compact mode,
which writes `compact.cirru` and `.compact-inc.cirru` instead of Clojure(Script).
And this project provides a runner for `compact.cirru`, written on Nim for low overhead.

A `compact.cirru` file can be:

```cirru
{} (:package |app)
  :configs $ {} (:init-fn |app.main/main!) (:reload-fn |app.main/reload!)
  :files $ {}
    |app.main $ {}
      :ns $ quote
        ns app.main $ :require
      :defs $ {}
        |main! $ quote
          defn main! () (+ 1 2)
        |reload! $ quote
          defn reload! ()
      :proc $ quote ()
```

APIs implemented in Calcit Runner is mostly learning from Clojure.

### Usage

Install dependency:

```bash
brew install fswatch sdl2 cairo
nimble test --threads:on -y
```

Build binaries:

```bash
nimble build --threads:on
```

There are currently 2 commands `cr` and `cr_once`:

```bash
cr compact.cirru # watch by default

cr compact.cirru --once # run only once

cr compact.cirru --init-fn='app.main/main!' # specifying init-fn

cr -e="range 100" # eval from CLI

cr --emit-js # compile to js
cr --emit-js --mjs # compile to mjs
cr --emit-js --emit-path=out/ # compile to js and save in `out/`

cr --emit-ir # compile to intermediate representation

cr_once # bundled without wathcer and SDL2, for CI only
```

For linux users, download pre-built binaries from http://bin.calcit-lang.org/linux/ .

### Development

Dependent modules, besides SDL2 and Cairo:

- [Cirru Parser](https://github.com/Cirru/parser.nim) for indentation-based syntax parsing.
- [Cirru EDN](https://github.com/Cirru/cirru-edn.nim) for `compact.cirru` file parsing.
- [Ternary Tree](https://github.com/calcit-lang/ternary-tree) for persistent list and map structure.
- [JSON Paint](https://github.com/calcit-lang/json-paint) for drawing shapes with canvas.
- [Dual Balanced Ternary](https://github.com/dual-balanced-ternary/dual-balanced-ternary.nim).

Alias in dev mode:

```bash
# rerun program on changes
nimble watch

# just run once
nimble once

# demo of eval from CLI
nimble e

# for emitting js
nimble genjs

# for emitting ir
nimble genir
```

### Modules

```cirru
:configs $ {}
  :modules $ [] |phlox/compact.cirru
```

Calcit Runner use `~/.config/calcit/modules/` as modules directory.
Paths defined in `:modules` field are just loaded as files based on this directory,
which is: `~/.config/calcit/modules/phlox.caclit.nim/compact.cirru`.

To load modules in CI environment, create that folder and clone repos manually.

### License

MIT
