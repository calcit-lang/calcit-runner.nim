
{} (:package |app)
  :configs $ {} (:init-fn |app.main/main!) (:reload-fn |app.main/reload!)
  :files $ {}
    |app.main $ {}
      :ns $ quote
        ns app.main $ :require
      :defs $ {}

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
            log-title "|Testing str"
            test-str

            log-title "|Testing keyword function"
            test-keyword

            log-title "|Testing detects"
            test-detects

            do true

      :proc $ quote ()
      :configs $ {} (:extension nil)
