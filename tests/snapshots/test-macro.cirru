
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

            let
                detect-x $ fn (x)
                  case x
                    1 "|one"
                    2 "|two"
                    x "|else"
              assert "|try case" $ &= (detect-x 1) "|one"
              assert "|try case" $ &= (detect-x 2) "|two"
              assert "|try case" $ &= (detect-x 3) "|else"

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
              macroexpand $ quote (\ + 2 %)
              quote $ fn (%) (+ 2 %)

            assert "|expand lambda" $ =
              macroexpand $ quote $ \ x
              quote $ fn (%) (x)

            assert "|expand lambda" $ =
              macroexpand $ quote $ \ + x %
              quote $ fn (%) (+ x %)

            assert "|expand lambda" $ =
              macroexpand $ quote $ \ + x % %2
              quote $ fn (% %2) (+ x % %2)

        |main! $ quote
          defn main! ()
            log-title "|Testing cond/case"
            test-cond

            log-title "|Testing thread macros"
            test-thread-macros

            echo "|Finished running test"
            do true

      :proc $ quote ()
      :configs $ {} (:extension nil)
