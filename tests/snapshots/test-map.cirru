
{} (:package |app)
  :configs $ {} (:init-fn |app.main/main!) (:reload-fn |app.main/reload!)
  :files $ {}
    |app.main $ {}
      :ns $ quote
        ns app.main $ :require
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

        |log-title $ quote
          defn log-title (title)
            echo
            echo title
            echo

        |main! $ quote
          defn main! ()

            log-title "|Testing maps"
            test-maps

            echo "|Finished running test"
            do true

      :proc $ quote ()
      :configs $ {} (:extension nil)
