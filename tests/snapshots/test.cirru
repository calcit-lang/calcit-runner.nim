
{} (:package |app)
  :configs $ {} (:init-fn |app.main/main!) (:reload-fn |app.main/reload!)
    :modules $ [] |./test-cond.cirru |./test-gynienic.cirru |./test-json.cirru
      , |./test-lens.cirru |./test-list.cirru |./test-macro.cirru |./test-map.cirru
      , |./test-math.cirru |./test-recursion.cirru |./test-set.cirru
      , |./test-string.cirru |./test-ternary.cirru
  :files $ {}
    |app.main $ {}
      :ns $ quote
        ns app.main $ :require
          [] test-cond.main :as test-cond
          [] test-gynienic.main :as test-gynienic
          [] test-json.main :as test-json
          [] test-lens.main :as test-lens
          [] test-list.main :as test-list
          [] test-macro.main :as test-macro
          [] test-map.main :as test-map
          [] test-math.main :as test-math
          [] test-recursion.main :as test-recursion
          [] test-set.main :as test-set
          [] test-string.main :as test-string
          [] test-ternary.main :as test-ternary
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
            &let
              base $ {} (:a 1)
              assert= 1 $ base :a

        |test-id $ quote
          fn ()
            assert= 9 $ count $ generate-id! 9
            assert= |aaaaa $ generate-id! 5 |a

        |test-detects $ quote
          defn test-detects ()
            assert "|function" $ fn? $ fn () 1
            assert "|function" $ fn? &=
            assert "|function" $ macro? cond

            assert "|set" $ set? $ #{} 1 2 3

            assert= 1 (either nil 1)
            assert= 2 (either 2 1)
            assert= nil (either nil nil)

            assert= 2 $ either 2
              raise "|should not be called"

            assert= 2 (def x 2)

            assert= false $ and true true false
            assert= false $ and true false true
            assert= true $ and true true true

            assert= false $ or false false false
            assert= true $ or false true false
            assert= true $ or false false true

            assert=
              or true (raise "|raise in or")
              , true
            assert=
              and false (raise "|raise in and")
              , false

        |test-time $ quote
          fn ()
            assert= 1605024000 $ parse-time |2020-11-11
            assert= "|2020-11-11 00:01:40 000000"
              format-time 1605024100 "|yyyy-MM-dd HH:mm:ss ffffff"
            assert= "|2020-11-11 00:01:40 123399"
              format-time 1605024100.1234 "|yyyy-MM-dd HH:mm:ss ffffff"
            echo $ format-time (now!) "|yyyy-MM-dd HH:mm:ss ffffff"

        |test-if $ quote
          fn ()
            log-title "|Testing if with nil"
            assert= (if false 1) (if nil 1)
            assert= (if false 1 2) (if nil 1 2)

        |test-display-stack $ quote
          fn ()
            log-title "|Testing display stack"
            display-stack "|show stack here"

        |main! $ quote
          defn main! ()
            log-title "|Testing keyword function"
            test-keyword

            log-title "|Testing detects"
            test-detects

            log-title "|Testing id"
            test-id

            log-title "|Testing time"
            ; "|skipped since CI uses a different timezone"
            ; test-time

            test-if

            test-display-stack

            test-cond/main!
            test-gynienic/main!
            test-json/main!
            test-lens/main!
            test-list/main!
            test-macro/main!
            test-map/main!
            test-math/main!
            test-recursion/main!
            test-set/main!
            test-string/main!
            test-ternary/main!

            do true

      :proc $ quote ()
      :configs $ {} (:extension nil)
