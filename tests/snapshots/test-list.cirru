
{} (:package |app)
  :configs $ {} (:init-fn |app.main/main!) (:reload-fn |app.main/reload!)
  :files $ {}
    |app.main $ {}
      :ns $ quote
        ns app.main $ :require
      :defs $ {}

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

        |test-groups $ quote
          defn test-groups ()

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

            assert "|section-by" $ =
              section-by 2 $ range 10
              []
                [] 0 1
                [] 2 3
                [] 4 5
                [] 6 7
                [] 8 9
            assert |section-by $ =
              section-by 3 $ range 10
              []
                [] 0 1 2
                [] 3 4 5
                [] 6 7 8
                [] 9

        |test-comma $ quote
          assert "|allow commas in lists" $ =
            [] 1 2 3 4
            [] 1 , 2 , 3 , 4

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

        |test-apply $ quote
          defn test-apply ()
            assert= 10 $ apply + $ [] 1 2 3 4
            assert= 10 $ + & $ [] 1 2 3 4

        |test-join $ quote
          fn ()
            assert= |1-2-3-4 $ join-str |- $ [] 1 2 3 4
            assert= | $ join-str |- $ []
            assert=
              &[] 1 10 2 10 3 10 4
              join 10 $ [] 1 2 3 4
            assert= ([]) $ join 10 $ []

        |test-repeat $ quote
          fn ()
            assert=
              repeat 5 :a
              [] :a :a :a :a :a
            assert=
              interleave ([] :a :b :c :d) ([] 1 2 3 4 5)
              [] :a 1 :b 2 :c 3 :d 4

        |log-title $ quote
          defn log-title (title)
            echo
            echo title
            echo

        |main! $ quote
          defn main! ()

            log-title "|Testing list"
            test-list

            log-title "|Testing foldl"
            test-foldl

            log-title "|Testing every/any"
            test-every

            log-title "|Testing groups"
            test-groups

            log-title "|Testing apply"
            test-apply

            log-title "|Testing join"
            test-join

            log-title "|Testing repeat"
            test-repeat

            do true

      :proc $ quote ()
      :configs $ {} (:extension nil)
