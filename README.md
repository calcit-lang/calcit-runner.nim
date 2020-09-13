
Calcit Runner in Nim
----

> (Under development) Run Calcit data directly with nim.

Calcit Editor was designed for Clojure(Script). It emits a snapshot file as well as `.clj(s)` files.
And a Clojure(Script) runtime is required for running such a program.
In latest Calcit Editor, settings `:compact-output? true` in `:configs` enables compact mode,
which writes `compact.cirru` and `.compact-inc.cirru` instead of Clojure(Script).
And this project provides a runner for `compact.cirru` directly, written on Nim for low overhead.

### Usage

Install dependency:

```bash
brew install fswatch
nimble install
```

Run in dev mode:

```bash
nimble cr
```

It also watches the changes and rerun program.

Notice the configs in `calcit.cirru`:

```cirru
{}
  :configs $ {}
    :compact-output? true
    :init-fn |app.main/main!
    :reload-fn |app.main/reload!
```

_Not ready for a release yet_

### License

MIT
