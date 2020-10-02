
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

            do true

        |test-maps $ quote
          defn test-maps ()
            assert "|check map size" $ = 2 $ count $ {} (:a 1) (:b 2)
            let
                dict $ merge
                  {} (:a 1) (:b 2)
                  {} (:c 3) (:d 5)
              assert "|check dict size" $ = 4 $ count dict
              assert |contains (contains dict :a)
              assert "|not contains" $ not (contains dict :a2)
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
              assert |concat $ =
                concat (range 10) (range 4)
                [] 0 1 2 3 4 5 6 7 8 9 0 1 2 3
              ; echo
                format-ternary-tree $ concat (range 10) (range 4)
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

        |test-str $ quote
          defn test-str ()
            assert |concat $ = (&str-concat |a |b) |ab
            assert |concat $ = (&str-concat 1 2) |12
            assert |concat $ = (str |a |b |c) |abc
            assert |concat $ = (str 1 2 3) |123
            assert |convert $ = (type-of (&str 1)) :string

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

            echo "|Finished running test"
            do true

      :proc $ quote ()
      :configs $ {} (:extension nil)
