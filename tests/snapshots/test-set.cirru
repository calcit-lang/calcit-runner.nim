
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

        |main! $ quote
          defn main! ()
            log-title "|Testing set"
            test-set

            do true

      :proc $ quote ()
      :configs $ {} (:extension nil)
