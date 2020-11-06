
{} (:package |app)
  :configs $ {} (:init-fn |app.main/main!) (:reload-fn |app.main/reload!)
  :files $ {}
    |app.lib $ {}
      :ns $ quote
        :ns app.lib
      :defs $ {}
        |add-2 $ quote
          defn add-2 (x) (&+ x 2)
        |add-11 $ quote
          defmacro add-11 (a b)
            let
                c 11
              echo "\"internal c:" a b c
              quote-replace $ do (echo "\"c is:" c)
                [] (~ a) (~ b) (, c) (~ c) (add-2 8)
    |app.main $ {}
      :ns $ quote
        ns app.main $ :require ([] app.lib :refer $ [] add-11)
      :defs $ {}
        |try-hygienic $ quote
          defn try-hygienic ()
            let
                c 4
              assert=
                add-11 1 2
                [] 1 2 4 11 10
              , true

      :proc $ quote ()
      :configs $ {} (:extension nil)
