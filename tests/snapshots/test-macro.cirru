
{} (:package |test-macro)
  :configs $ {} (:init-fn |test-macro.main/main!) (:reload-fn |test-macro.main/reload!)
  :files $ {}
    |test-macro.main $ {}
      :ns $ quote
        ns test-macro.main $ :require
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
              assert= (compare-x 11) "|>10"
              assert= (compare-x 10) "|>5"
              assert= (compare-x 6) "|>5"
              assert= (compare-x 4) "|<=5"

        |test-case $ quote
          defn test-case ()
            let
                detect-x $ fn (x)
                  case x
                    1 "|one"
                    2 "|two"
                    x "|else"
              assert= (detect-x 1) "|one"
              assert= (detect-x 2) "|two"
              assert= (detect-x 3) "|else"

        |test-expr-in-case $ quote
          defn test-expr-in-case ()
            assert= |5
              case (+ 1 4)
                (+ 2 0) |2
                (+ 2 1) |3
                (+ 2 2) |4
                (+ 2 3) |5
                (+ 2 4) |6

        |test-thread-macros $ quote
          defn test-thread-macros ()
            assert=
              macroexpand $ quote $ -> a b c
              quote (c (b a))

            assert=
              macroexpand $ quote $ -> a (b) c
              quote (c (b a))

            assert=
              macroexpand $ quote $ -> a (b c)
              quote (b a c)

            assert=
              macroexpand $ quote $ -> a (b c) (d e f)
              quote (d (b a c) e f)

            assert=
              macroexpand $ quote $ ->> a b c
              quote (c (b a))

            assert=
              macroexpand $ quote $ ->> a (b) c
              quote (c (b a))

            assert=
              macroexpand $ quote $ ->> a (b c)
              quote (b c a)

            assert=
              macroexpand $ quote $ ->> a (b c) (d e f)
              quote (d e f (b c a))

            assert-detect identity $ contains-symbol?
              quote $ add $ + 1 %
              , '%

            assert-detect not $ contains-symbol?
              quote $ add $ + 1 2
              , '%

            assert=
              map (\ + 1 %) (range 3)
              range 1 4
            assert=
              map-indexed (\ [] % (&str %2)) (range 3)
              []
                [] 0 |0
                [] 1 |1
                [] 2 |2

            assert=
              macroexpand-all $ quote (\ + 2 %)
              quote $ defn f% (%) (+ 2 %)

            assert=
              macroexpand-all $ quote $ \ x
              quote $ defn f% (%) (x)

            assert=
              macroexpand-all $ quote $ \ + x %
              quote $ defn f% (%) (+ x %)

            assert=
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

            ; echo $ macroexpand $ quote $ call-with-log + 1 2 3 4
            assert= 10 $ call-with-log + 1 2 3 4

            &reset-gensym-index!

            assert=
              macroexpand $ quote
                defn-with-log f1 (a b) (+ a b)
              quote
                defn f1 (a b)
                  &let
                    f1 (defn f1 (a b) (+ a b))
                    call-with-log f1 a b

            ; echo $ macroexpand $ quote
              defn-with-log f1 (a b) (+ a b)
            let
                f2 $ defn-with-log f1 (a b) (+ a b)
              assert= 7 $ f2 3 4
              assert= 11 $ f2 & ([] 5 6)

        |test-with-cpu-time $ quote
          fn ()
            log-title "|Testing with-cpu-time"

            &reset-gensym-index!

            assert=
              macroexpand $ quote $ with-cpu-time $ + 1 2
              quote
                let
                    started__1 $ cpu-time
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

        |test-assert $ quote
          fn ()
            log-title "|Assert in different order"
            assert (= 1 1) |string
            assert |string (= 1 1)

        |test-extract $ quote
          fn ()
            log-title "|Extract map via keywords"

            &reset-gensym-index!

            assert=
              macroexpand $ quote $ let{}
                (a b) o
                + a b
              quote $ &let (result__1 o)
                let
                    a $ :a result__1
                    b $ :b result__1
                  + a b

            &let
              base $ {}
                :a 5
                :b 6
              assert= 11 $ let{}
                (a b) base
                + a b

        |test-detector $ quote
          fn ()
            log-title "|Detector function"

            &reset-gensym-index!

            assert=
              macroexpand $ quote $ assert-detect fn? $ fn () 1
              quote
                &let
                  v__1 (fn () 1)
                  if (fn? v__1) nil
                    do (echo)
                      echo (quote (fn () 1)) "|does not satisfy:" (quote fn?) "| <--------"
                      echo "|  value is:" v__1
                      raise "|Not satisfied in assertion!"

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

            test-assert

            test-extract

            test-detector

            do true

      :proc $ quote ()
      :configs $ {} (:extension nil)
