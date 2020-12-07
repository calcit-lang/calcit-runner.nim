
{} (:package |app)
  :configs $ {} (:init-fn |app.main/main!) (:reload-fn |app.main/reload!)
  :files $ {}
    |app.main $ {}
      :ns $ quote
        ns app.main $ :require
      :defs $ {}

        |log-title $ quote
          defn log-title (title)
            echo
            echo title
            echo

        |test-cond $ quote
          defn test-cond ()
            let
                compare-x $ fn (x)
                  cond
                    (&> x 10) "|>10"
                    (&> x 5) "|>5"
                    true "|<=5"
              assert "|try cond" $ &= (compare-x 11) "|>10"
              assert "|try cond" $ &= (compare-x 10) "|>5"
              assert "|try cond" $ &= (compare-x 6) "|>5"
              assert "|try cond" $ &= (compare-x 4) "|<=5"

        |test-case $ quote
          defn test-case ()
            let
                detect-x $ fn (x)
                  case x
                    1 "|one"
                    2 "|two"
                    x "|else"
              assert "|try case" $ &= (detect-x 1) "|one"
              assert "|try case" $ &= (detect-x 2) "|two"
              assert "|try case" $ &= (detect-x 3) "|else"

        |test-expr-in-case $ quote
          defn test-expr-in-case ()
            assert "|try expr in case" $ = |5
              case (+ 1 4)
                (+ 2 0) |2
                (+ 2 1) |3
                (+ 2 2) |4
                (+ 2 3) |5
                (+ 2 4) |6

        |test-thread-macros $ quote
          defn test-thread-macros ()
            assert "|try -> macro" $ &=
              macroexpand $ quote $ -> a b c
              quote (c (b a))

            assert "|try -> macro" $ &=
              macroexpand $ quote $ -> a (b) c
              quote (c (b a))

            assert "|try -> macro" $ &=
              macroexpand $ quote $ -> a (b c)
              quote (b a c)

            assert "|try -> macro" $ &=
              macroexpand $ quote $ -> a (b c) (d e f)
              quote (d (b a c) e f)

            assert "|try ->> macro" $ &=
              macroexpand $ quote $ ->> a b c
              quote (c (b a))

            assert "|try ->> macro" $ &=
              macroexpand $ quote $ ->> a (b) c
              quote (c (b a))

            assert "|try ->> macro" $ &=
              macroexpand $ quote $ ->> a (b c)
              quote (b c a)

            assert "|try ->> macro" $ &=
              macroexpand $ quote $ ->> a (b c) (d e f)
              quote (d e f (b c a))

            assert "|contains-symbol?" $ contains-symbol?
              quote $ add $ + 1 %
              , '%

            assert "|contains-symbol?" $ not $ contains-symbol?
              quote $ add $ + 1 2
              , '%

            assert "|lambda" $ =
              map (\ + 1 %) (range 3)
              range 1 4
            assert "|lambda" $ =
              map-indexed (\ [] % (&str %2)) (range 3)
              []
                [] 0 |0
                [] 1 |1
                [] 2 |2

            assert "|expand lambda" $ =
              macroexpand-all $ quote (\ + 2 %)
              quote $ defn f% (%) (+ 2 %)

            assert "|expand lambda" $ =
              macroexpand-all $ quote $ \ x
              quote $ defn f% (%) (x)

            assert "|expand lambda" $ =
              macroexpand-all $ quote $ \ + x %
              quote $ defn f% (%) (+ x %)

            assert "|expand lambda" $ =
              macroexpand-all $ quote $ \ + x % %2
              quote $ defn f% (% %2) (+ x % %2)

            &reset-gensym-index!

            assert=
              macroexpand-all $ quote
                case (+ 1 2)
                  1 |one
                  2 |two
                  3 |three
              quote
                &let (v__1 (+ 1 2))
                  if (&= v__1 1) |one
                    if (&= v__1 2) |two
                      if (&= v__1 3) |three nil
            assert=
              macroexpand $ quote
                case (+ 1 2)
                  1 |one
                  2 |two
                  3 |three
              quote
                &let (v__2 (+ 1 2))
                  &case v__2
                    1 |one
                    2 |two
                    3 |three
            assert=
              macroexpand $ quote
                &case v__2
                  1 |one
                  2 |two
                  3 |three
              quote
                if (&= v__2 1) |one
                  &case v__2
                    2 |two
                    3 |three

        |test-let $ quote
          fn ()
            assert= 3
              let->
                let a 1
                let b 2
                + b a

        |test-gensym $ quote
          fn ()
            &reset-gensym-index!
            assert= (gensym) 'G__1
            assert=
              gensym 'a
              , 'a__2
            assert=
              gensym |a
              , 'a__3

        |test-with-log $ quote
          fn ()
            log-title "|Testing with-log"

            &reset-gensym-index!

            assert=
              macroexpand $ quote $ with-log $ + 1 2
              quote $ &let
                v__1 $ + 1 2
                echo (quote $ + 1 2) |=> v__1
                , v__1
            assert=
              with-log $ + 1 2
              , 3

        |test-with-cpu-time $ quote
          fn ()
            log-title "|Testing with-cpu-time"

            &reset-gensym-index!

            assert=
              macroexpand $ quote $ with-cpu-time $ + 1 2
              quote $ &let
                started__1 $ cpu-time
                &let
                  v__2 $ + 1 2
                  echo |[cpu-time]
                    quote $ + 1 2
                    , |=>
                    format-number (&* 1000 (&- (cpu-time) started__1)) 3
                    , |ms
                  , v__2
            assert=
              with-cpu-time $ + 1 2
              , 3
            assert=
              with-cpu-time $ &+ 1 2
              , 3

        |main! $ quote
          defn main! ()
            log-title "|Testing cond"
            test-cond

            log-title "|Testing case"
            test-case

            log-title "|Testing expr in case"
            test-expr-in-case

            log-title "|Testing thread macros"
            test-thread-macros

            log-title "|Testing let thread"
            test-let

            log-title "|Testing gensym"
            test-gensym

            test-with-log

            test-with-cpu-time

            do true

      :proc $ quote ()
      :configs $ {} (:extension nil)
