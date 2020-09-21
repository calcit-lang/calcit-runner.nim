
{} (:package |app)
  :configs $ {} (:init-fn |app.main/main!) (:reload-fn |app.main/reload!)
  :files $ {}
    |app.main $ {}
      :ns $ quote
        ns app.main $ :require ([] app.lib :refer $ [] show-info) ([] app.lib :as lib)
      :defs $ {}
        |try-let $ quote
          defn try-let ()
            let
                a $ + 10 10
              echo "\"reloaded... 7" a
        |try-macro $ quote
          defn try-macro ()
            eval $ quote (println $ + 1 2)
            println $ quote (+ 1 2)
            println $ gen-num 3 4 c
            println "\"inserting:" $ insert-x 1 2 (3 4 5 $ + 7 8)
        |main! $ quote
          defn main! () (println "\"Loaded program!") (; try-let) (; try-func) (; try-macro) (try-hygienic)
        |try-hygienic $ quote
          defn try-hygienic ()
            let
                c 2
              echo $ add-11 1 2
        |fibo $ quote
          defn fibo (x)
            if (< x 2) (, 1)
              + (fibo $ - x 1) (fibo $ - x 2)
        |add-11 $ quote
          defmacro add-11 (a b)
            let
                c 11
              echo "\"internal c:" a b c
              quote-replace $ do (echo "\"c is:" c)
                + (quote-insert a) (quote-insert b) (, c)
        |insert-x $ quote
          defmacro insert-x (a b c)
            quote-replace $ do
              echo $ + (quote-insert a) (quote-insert b)
              echo $ quote-insert-list c
        |gen-num $ quote
          defmacro gen-num (a b c) (echo a b c) (quote $ + 1 2 3)
        |reload! $ quote
          defn reload! () (println "\"Reloaded...") (main!)
        |try-func $ quote
          defn try-func () (echo "\"Running demo" $ demo 1 4) (show-info 1) (lib/show-info 2) (pr-str 1 "\"2" true) (; echo "\"fibo result:" $ fibo 16)
        |demo $ quote
          defn demo (x y) (echo "\"adding:" x y "\"result is" $ + x y)
      :proc $ quote ()
      :configs $ {} (:extension nil)
    |app.lib $ {}
      :ns $ quote (ns app.lib)
      :defs $ {}
        |show-info $ quote
          defn show-info (x) (echo "\"information blabla" x)
      :proc $ quote ()
      :configs $ {}
