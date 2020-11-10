
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

        |test-lens $ quote
          defn test-lens ()
            assert "|assoc-in" $ =
              assoc-in
                {} $ :a $ {} $ :b $ {}
                [] :a :b
                , 10
              {} $ :a $ {} $ :b 10
            assert "|assoc-in" $ =
              assoc-in
                {} $ :a $ [] 1 2 3
                [] :a 1
                , 10
              {} $ :a $ [] 1 10 3
            assert "|update-in" $ =
              update-in
                {} $ :a $ {} $ :b $ {} $ :c 2
                [] :a :b :c
                , inc
              {} $ :a $ {} $ :b $ {} $ :c 3
            assert "|update-in" $ =
              update-in
                {} $ :a $ [] 1 2 3
                [] :a 1
                , inc
              {} $ :a $ [] 1 3 3
            assert |dissoc-in $ =
              dissoc-in
                {} $ :a $ {} $ :b $ {} $ :c 2
                [] :a :b :c
              {} $ :a $ {} $ :b $ {}
            assert=
              dissoc-in
                {} $ :a $ [] 1 2 3
                [] :a 1
              {} $ :a $ [] 1 3
            assert=
              get-in
                {} $ :a $ {} $ :b $ {} $ :c 3
                [] :a :b :c
              , 3
            assert=
              get-in
                {} $ :a $ [] 1 2 3
                [] :a 1
              , 2

        |main! $ quote
          defn main! ()

            log-title "|Testing lens"
            test-lens

            do true

      :proc $ quote ()
      :configs $ {} (:extension nil)
