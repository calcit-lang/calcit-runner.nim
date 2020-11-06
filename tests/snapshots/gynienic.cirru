
{} (:package |app)
  :configs $ {} (:init-fn |app.main/main!) (:reload-fn |app.main/reload!)
  :files $ {}
    |app.lib $ {}
      :ns $ quote
        :ns app.lig
      :defs $ {}
        |add-11 $ quote
          defmacro add-11 (a b)
            let
                c 11
              echo "\"internal c:" a b c
              quote-replace $ do (echo "\"c is:" c)
                + (~ a) (~ b) (, c)
    |app.main $ {}
      :ns $ quote
        ns app.main $ :require ([] app.lib :refer $ [] add-11)
      :defs $ {}
        |try-hygienic $ quote
          defn try-hygienic ()
            let
                c 2
                ret $ add-11 1 2
              echo ret
              , ret

      :proc $ quote ()
      :configs $ {} (:extension nil)
