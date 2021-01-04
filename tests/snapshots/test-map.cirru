
{} (:package |test-map)
  :configs $ {} (:init-fn |test-map.main/main!) (:reload-fn |test-map.main/reload!)
  :files $ {}
    |test-map.main $ {}
      :ns $ quote
        ns test-map.main $ :require
      :defs $ {}

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

              assert |vals $ =
                vals $ {} (:a 1) (:b 2) (:c 2)
                [] 2 1 2

              assert=
                merge-non-nil
                  {,} :a 1 , :b 2 , :c 3
                  {,} :a nil , :b 12
                  {,} :c nil , :d 14
                {,} :a 1 , :b 12 , :c 3 , :d 14

        |test-pairs $ quote
          fn ()

            assert |pairs-map $ =
              pairs-map $ []
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

            assert=
              map-kv
                fn (k v) ([] k (+ v 1))
                {} (:a 1) (:b 2)
              [][] (:a 2) (:b 3)

        |test-native-map-syntax $ quote
          defn test-native-map-syntax ()
            assert "|internally {} is a macro" $ =
              macroexpand $ quote $ {} (:a 1)
              quote $ &{} ([] :a 1)

        |log-title $ quote
          defn log-title (title)
            echo
            echo title
            echo

        |test-map-comma $ quote
          fn ()
            log-title "|Testing {,}"
            assert=
              macroexpand $ quote $ {,} :a 1 , :b 2 , :c 3
              quote $ pairs-map $ section-by 2 $ [] :a 1 :b 2 :c 3
            assert=
              {,} :a 1 , :b 2 , :c 3
              {} (:a 1) (:b 2) (:c 3)

        |main! $ quote
          defn main! ()

            log-title "|Testing maps"
            test-maps

            log-title "|Testing map pairs"
            test-pairs

            log-title "|Testing map syntax"
            test-native-map-syntax

            test-map-comma

            do true

      :proc $ quote ()
      :configs $ {} (:extension nil)
