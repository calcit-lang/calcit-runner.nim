
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

        |test-maps $ quote
          defn test-maps ()
            assert "|check map size" $ = 2 $ count $ {} (:a 1) (:b 2)
            let
                dict $ merge
                  {} (:a 1) (:b 2)
                  {} (:c 3) (:d 5)
              assert "|check dict size" $ = 4 $ count dict
              assert |contains (contains? dict :a)
              assert "|not contains" $ not (contains? dict :a2)
              ; echo $ keys dict
              assert "|keys" $ = (keys dict) ([] :c :a :b :d)
              assert |assoc $ = (assoc dict :h 10) $ {}
                :a 1
                :b 2
                :c 3
                :d 5
                :h 10
              assert |dissoc $ = (dissoc dict :a) $ {}
                :b 2
                :c 3
                :d 5
              assert |same $ = dict (dissoc dict :h)
              assert |merge $ =
                merge
                  {}
                    :a 1
                    :b 2
                  {}
                    :c 3
                  {}
                    :d 4
                {} (:a 1) (:b 2) (:c 3) (:d 4)

              assert |pair-map $ =
                pair-map $ []
                  [] :a 1
                  [] :b 2
                {} (:a 1) (:b 2)

              assert |zipmap $ =
                zipmap
                  [] :a :b :c
                  [] 1 2 3
                {}
                  :a 1
                  :b 2
                  :c 3

              assert |to-pairs $ =
                to-pairs $ {}
                  :a 1
                  :b 2
                []
                  [] :a 1
                  [] :b 2

              assert |vals $ =
                vals $ {} (:a 1) (:b 2) (:c 2)
                [] 2 1 2

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

        |test-list $ quote
          defn test-list ()
            let
                a $ [] 1 2 3
              assert "|compare list" $ = a $ [] 1 2 3
              assert "|prepend" $ = (prepend a 4) $ [] 4 1 2 3
              assert "|append" $ = (append a 4) $ [] 1 2 3 4
              assert "|first" $ = 1 (first a)
              assert "|last" $ = 3 (last a)
              assert "|gets nil" $ nil? (first $ [])
              assert "|gets nil" $ nil?  (last $ [])
              assert "|rest" $ = (rest a) $ [] 2 3
              assert |rest $ nil? (rest $ [])
              assert |butlast $ = (butlast a) ([] 1 2)
              assert |butlast $ nil? (butlast $ [])
              assert |range $ = (range 0) $ []
              assert |range $ = (range 1) $ [] 0
              assert |range $ = (range 4) $ [] 0 1 2 3
              assert |range $ = (range 4 5) $ [] 4
              assert |range $ = (range 4 10) $ [] 4 5 6 7 8 9
              assert |slice $ = (slice (range 10) 0 10) (range 10)
              assert |slice $ = (slice (range 10) 5 7) ([] 5 6)
              assert |&concat $ =
                &concat (range 10) (range 4)
                [] 0 1 2 3 4 5 6 7 8 9 0 1 2 3
              assert "|concat only 1" $ =
                concat $ [] 1 2 3
                [] 1 2 3
              assert "|concat lists" $ =
                concat ([] 1 2) ([] 4 5) ([] 7 8)
                [] 1 2 4 5 7 8
              ; echo
                format-ternary-tree $ &concat (range 10) (range 4)
              ; echo $ format-ternary-tree
                assoc-before (range 8) (, 4 22)
              ; echo $ format-ternary-tree
                assoc-after (range 8) (, 4 22)
              assert |assoc $ =
                assoc (range 10) (, 4 55)
                [] 0 1 2 3 55 5 6 7 8 9
              assert |dissoc $ =
                dissoc (range 10) 4
                [] 0 1 2 3 5 6 7 8 9
              assert |take $ = (take 4 $ range 10) $ [] 0 1 2 3
              assert |drop $ = (drop 4 $ range 10) ([] 4 5 6 7 8 9)
              echo $ format-ternary-tree $ reverse $ [] |a |b |c |d |e
              echo $ format-ternary-tree $ [] |e |d |c |b a
              assert |reverse $ =
                reverse $ [] |a |b |c |d |e
                [] |e |d |c |b |a

              assert "|map and concat" $ =
                mapcat
                  fn (x) (range x)
                  [] 1 2 3 4
                [] 0 0 1 0 1 2 0 1 2 3

              assert |identity $ =
                map identity $ range 10
                range 10

              assert |map-indexed $ =
                map-indexed (fn (idx x) ([] idx (&str x))) (range 3)
                []
                  [] 0 |0
                  [] 1 |1
                  [] 2 |2

              assert |filter $ =
                filter (fn (x) (&> x 3)) (range 10)
                [] 4 5 6 7 8 9

              assert |filter-not $ =
                filter-not (fn (x) (&> x 3)) (range 10)
                [] 0 1 2 3

              assert |rand-nth $ <= 0
                index-of (range 10) $ rand-nth $ range 10

              assert |rand-nth $ nil? $ rand-nth ([])

              assert "|contains in list" $ contains? (range 10) 6
              assert "|contains in list" $ not $ contains? (range 10) 16

              assert "|has-index?" $ has-index? (range 4) 3
              assert "|has-index?" $ not $ has-index? (range 4) 4
              assert "|has-index?" $ not $ has-index? (range 4) -1

              assert "|update map" $ =
                update ({} (:a 1)) :a $ \ + % 10
                {} (:a 11)

              assert "|update map" $ =
                update ({} (:a 1)) :c $ \ + % 10
                {} (:a 1)

              assert "|update list" $ =
                update (range 4) 1 $ \ + % 10
                [] 0 11 2 3
              assert "|update list" $ =
                update (range 4) 11 $ \ + % 10
                range 4

              assert "|group-by" $ =
                group-by
                  \ mod % 3
                  range 10
                {}
                  0 $ [] 0 3 6 9
                  1 $ [] 1 4 7
                  2 $ [] 2 5 8

              assert "|frequencies" $ =
                frequencies $ [] 1 2 2 3 3 3
                {}
                  1 1
                  2 2
                  3 3

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

        |test-foldl $ quote
          defn test-foldl ()
            assert "|get" $ = 1 $ get ([] 1 2 3) 0
            assert "|foldl" $ = 6 $ foldl &+ ([] 1 2 3) 0
            assert |add $ = (+ 1 2 3 4 (+ 5 6 7)) 28
            assert "|minus" $ = -1 (- 1 2)
            assert |minus $ = -7 (- 4 5 6)
            assert |minus $ = 91 (- 100 $ - 10 1)
            assert "|compare" $ foldl-compare &< ([] 1 2) 0
            assert "|compare" (< 1 2 3 4)
            assert |compare $ not (< 3 2)
            assert |mutiply $ = (* 2 3) 6
            assert |mutiply $ = (* 2 3 4) 24
            assert |divide $ = (/ 2 3) (/ 4 6)
            assert |divide $ = (/ 2 3 4) (/ 1 6)

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


        |test-every $ quote
          defn test-every ()
            let
                data $ [] 1 2 3 4
              assert "|try every?" $ not $ every?
                fn (x) (&> x 1)
                , data
              assert "|try every?" $ every?
                fn (x) (&> x 0)
                , data
              assert "|try any?" $ any?
                fn (x) (&> x 3)
                , data
              assert "|try any?" $ not $ any?
                fn (x) (&> x 4)
                , data

            assert "|some?" $ some? 1
            assert "|some?" $ not $ some? nil

        |test-keyword $ quote
          defn test-keyword ()
            assert "|keyword function" $ =
              :a ({} (:a 1))
              , 1
            assert "|keyword used at nil" $ =
              :a nil
              , nil

        |main! $ quote
          defn main! ()
            log-title "|Testing numbers"
            test-numbers

            log-title "|Testing maps"
            test-maps

            log-title "|Testing hole series"
            test-hole-series

            log-title "|Testing list"
            test-list

            log-title "|Testing foldl"
            test-foldl

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

            log-title "|Testing every/any"
            test-every

            log-title "|Testing keyword function"
            test-keyword

            echo "|Finished running test"
            do true

      :proc $ quote ()
      :configs $ {} (:extension nil)
