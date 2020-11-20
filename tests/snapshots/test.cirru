
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

            assert= 1 (either nil 1)
            assert= 2 (either 2 1)
            assert= nil (either nil nil)

            assert= 2 $ either 2
              raise "|should not be called"

            assert= 2 (def x 2)

            assert= false $ and
            assert= false $ or

            assert= false $ and true true false
            assert= false $ and true false true
            assert= true $ and true true true

            assert= false $ or false false false
            assert= true $ or false true false
            assert= true $ or false false true

        |main! $ quote
          defn main! ()
            log-title "|Testing keyword function"
            test-keyword

            log-title "|Testing detects"
            test-detects

            do true

      :proc $ quote ()
      :configs $ {} (:extension nil)
