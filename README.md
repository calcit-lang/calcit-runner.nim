
Calcit Runner
----

> (Under development) Run Calcit data directly with nim.

Running [Calcit Editor](https://github.com/Cirru/calcit-editor#compact-output) with `compact=true caclcit-editor` enables compact mode,
which writes `compact.cirru` and `.compact-inc.cirru` instead of Clojure(Script).
And this project provides a runner for `compact.cirru`, written on Nim for low overhead.

Dependent modules:

- [Cirru Parser](https://github.com/Cirru/parser.nim) for indentation-based syntax parsing.
- [Cirru EDN](https://github.com/Cirru/cirru-edn.nim) for `compact.cirru` file parsing.
- [Ternary Tree](https://github.com/Cirru/ternary-tree) for persistent list and map structure.
- [JSON Paint](https://github.com/Quamolit/json-paint.nim) for drawing shapes with canvas.
- [Dual Balanced Ternary](https://github.com/dual-balanced-ternary/dual-balanced-ternary.nim).

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

Syntax implemented in Calcit Runner is mostly learning from Clojure. Browse current APIs at http://repo.cirru.org/calcit-runner-apis/ .

### Usage

Install dependency:

```bash
brew install fswatch sdl2 cairo
nimble test --threads:on -y
```

Run in dev mode:

```bash
# rerun program on changes
nimble watch

# just run once
nimble once

# demo of eval from CLI
nimble e
```

If you build `cr` with `nimble build --threads:on`, just

```bash
cr compact.cirru # run and wath

cr compact.cirru --once # run only once

cr -e="echo $ range 100" # eval from CLI
```

_Not ready for a release yet_


### Modules

```cirru
:configs $ {}
  :modules $ [] |phlox.caclit.nim/compact.cirru
```

Calcit Runner use `~/.config/calcit/modules/` as modules directory.
Paths defined in `:modules` field are just loaded as files based on this directory,
which is: `~/.config/calcit/modules/phlox.caclit.nim/compact.cirru`.

### License

MIT
