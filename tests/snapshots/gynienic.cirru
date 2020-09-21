
{} (:package |app)
  :configs $ {} (:init-fn |app.main/main!) (:reload-fn |app.main/reload!)
  :files $ {}
    |app.main $ {}
      :ns $ quote
        ns app.main $ :require ([] app.lib :refer $ [] show-info) ([] app.lib :as lib)
      :defs $ {}
        |main! $ quote
          defn main! () (try-hygienic)
        |try-hygienic $ quote
          defn try-hygienic ()
            let
                c 2
              add-11 1 2
        |add-11 $ quote
          defmacro add-11 (a b)
            let
                c 11
              echo "\"internal c:" a b c
              quote-replace $ do (echo "\"c is:" c)
                + (quote-insert a) (quote-insert b) (, c)

      :proc $ quote ()
      :configs $ {} (:extension nil)
