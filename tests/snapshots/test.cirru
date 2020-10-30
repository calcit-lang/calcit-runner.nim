
{} (:package |app)
  :configs $ {} (:init-fn |app.main/main!) (:reload-fn |app.main/reload!)
  :files $ {}
    |app.main $ {}
      :ns $ quote
        ns app.main $ :require
      :defs $ {}
        |test-numbers $ quote
          defn test-numbers ()
            assert "|simple add" $ = 3 (+ 1 2)
            assert |add $ = 10 (+ 1 2 3 4)
            assert |minus $ = 4 (- 10 1 2 3)
            assert |mutiply $ = 24 (* 1 2 3 4)
            assert |divide $ = 15 (/ 360 2 3 4)
            assert |littler $ < 1 2 3 4 5
            assert |larger $ > 10 8 6 4
            assert |empty $ empty? nil
            assert "|empty vector" $ empty? ([])

            assert "|rand" $ <= 0 (rand) 100
            assert "|rand" $ <= 0 (rand 10) 10
            assert "|rand" $ <= 20 (rand 20 30) 30

            assert "|rand-int" $ <= 0 (rand-int) 100
            assert "|rand-int" $ <= 0 (rand-int 10) 10
            assert "|rand-int" $ <= 20 (rand-int 20 30) 30

            do true

        |hole-series $ quote
          defn hole-series (x)
            if (&<= x 0) (raise-at "\"unexpected small number" x)
              if (&= x 1) (, 0)
                if (&= x 2) (, 1)
                  let
                      extra $ mod x 3
                    if (&= extra 0)
                      let
                          unit $ &/ x 3
                        &* 3 $ hole-series unit
                      if (&= extra 1)
                        let
                            unit $ &/ (&- x 1) (, 3)
                          &+ (&* 2 $ hole-series unit) (hole-series $ &+ unit 1)
                        let
                            unit $ &/ (&- x 2) (, 3)
                          &+
                            &* 2 $ hole-series (&+ unit 1)
                            hole-series unit

        |test-hole-series $ quote
          defn test-hole-series ()
            assert "|hole series numbers" $ = (map hole-series (range 1 20))
              [] 0 1 0 1 2 3 2 1 0 1 2 3 4 5 6 7 8 9 8

        |test-str $ quote
          defn test-str ()
            assert "|string concat" $ = (&str-concat |a |b) |ab
            assert "|string concat" $ = (&str-concat 1 2) |12
            assert "|string concat" $ = (str |a |b |c) |abc
            assert "|string concat" $ = (str 1 2 3) |123
            assert |convert $ = (type-of (&str 1)) :string
            assert "|string replace" $ =
              replace "|this is a" |is |IS
              , "|thIS IS a"
            assert "|string splitting" $ =
              split "|a,b,c" "|,"
              [] |a |b |c
            assert "|string splitting" $ =
              split-lines "|a\nb\nc"
              [] |a |b |c

        |log-title $ quote
          defn log-title (title)
            echo
            echo title
            echo

        |test-math $ quote
          defn test-math ()
            echo "|sin 1" $ sin 1
            echo "|cos 1" $ cos 1
            assert "|sin and cos" $ = 1 $ + (pow (sin 1) 2) (pow (cos 1) 2)
            assert |floor $ = 1 $ floor 1.1
            assert |ceil $ = 2 $ ceil 1.1
            assert |round $ = 1 $ round 1.1
            assert |round $ = 2 $ round 1.8
            assert |pow $ = 81 $ pow 3 4
            assert |mod $ = 1 $ mod 33 4
            assert |sqrt $ = 9 $ sqrt 81
            echo |PI &PI
            echo |E &E

        |test-set $ quote
          defn test-set ()
            assert "|init set" $ = 4 $ count $ #{} 1 2 3 4
            assert "|contains" $ contains? (#{} 1 2 3) 2
            assert "|not contains" $ = false $ contains? (#{} 1 2 3) 4
            assert "|equals" $ = (#{} 1 2 3) (#{} 2 3 1)
            assert "|include" $ = (include (#{} 1 2 3) 4) (#{} 1 2 3 4)
            assert "|include" $ = (include (#{} 1 2) 3 4) (#{} 1 2 3 4)
            assert "|exclude" $ = (exclude (#{} 1 2 3) 1) (#{} 2 3)
            assert "|exclude" $ = (exclude (#{} 1 2 3) 1 2) (#{} 3)

            assert "|difference" $ =
              difference (#{} 1 2 3) (#{} 1) (#{} 2)
              #{} 3
            assert "|union" $ =
              union (#{} 1) (#{} 2) (#{} 3)
              #{} 1 2 3
            assert "|intersection" $ =
              intersection (#{} 1 2 3) (#{} 2 3 4) (#{} 3 4 5)
              #{} 3

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

        |test-compare $ quote
          defn test-compare ()
            assert "|find max" $ = 4 $ max $ [] 1 2 3 4
            assert "|find min" $ = 1 $ min $ [] 1 2 3 4

            assert "|not equal" $ /= 1 2

        |test-keyword $ quote
          defn test-keyword ()
            assert "|keyword function" $ =
              :a ({} (:a 1))
              , 1
            assert "|keyword used at nil" $ =
              :a nil
              , nil

        |test-detects $ quote
          defn test-detects ()
            assert "|function" $ fn? $ fn () 1
            assert "|function" $ fn? &=
            assert "|function" $ macro? cond

        |main! $ quote
          defn main! ()
            log-title "|Testing numbers"
            test-numbers

            log-title "|Testing hole series"
            test-hole-series

            log-title "|Testing str"
            test-str

            log-title "|Testing math"
            test-math

            log-title "|Testing set"
            test-set

            log-title "|Testing cond/case"
            test-cond

            log-title "|Testing thread macros"
            test-thread-macros

            log-title "|Testing compare"
            test-compare

            log-title "|Testing keyword function"
            test-keyword

            log-title "|Testing detects"
            test-detects

            echo "|Finished running test"
            do true

      :proc $ quote ()
      :configs $ {} (:extension nil)
