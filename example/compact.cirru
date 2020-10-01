
{} (:package |app)
  :configs $ {} (:init-fn |app.main/main!) (:reload-fn |app.main/reload!)
  :files $ {}
    |app.main $ {}
      :ns $ quote
        ns app.main $ :require ([] app.lib :refer $ [] show-info) ([] app.lib :as lib)
      :defs $ {}
        |try-maps $ quote
          defn try-maps ()
            echo $ {} (:a 1) (:b 2)
            let
                dict $ merge
                  {} (:a 1) (:b 2)
                  {} (:c 3) (:d 5)
              echo dict
              echo (contains dict :a) (contains dict :a2)
              echo $ keys dict
              echo (assoc dict :h 10) (dissoc dict :a) (dissoc dict :h)
        |try-let $ quote
          defn try-let ()
            let
                a $ + 10 10
              echo "\"reloaded... 7" a
        |hole-series $ quote
          defn hole-series (x)
            if (&<= x 0) (raise-at "\"unexpected small number" x)
              if (&= x 1) (, 0)
                if (&= x 2) (, 1)
                  let
                      extra $ mod x 3
                    if (&= extra 0)
                      let
                          unit $ &/ x 3
                        &* 3 $ hole-series unit
                      if (&= extra 1)
                        let
                            unit $ &/ (&- x 1) (, 3)
                          &+ (&* 2 $ hole-series unit) (hole-series $ &+ unit 1)
                        let
                            unit $ &/ (&- x 2) (, 3)
                          &+
                            &* 2 $ hole-series (&+ unit 1)
                            hole-series unit
        |try-macro $ quote
          defn try-macro ()
            eval $ quote (println $ + 1 2)
            println $ quote (+ 1 2)
            println $ gen-num 3 4 c
            raise
            println "\"inserting:" $ insert-x 1 2 (3 4 5 $ + 7 8)
            echo $ macroexpand (quote $ gen-num 1 3 4)
        |main! $ quote
          defn main! () (println "\"Loaded program!") (; try-let) (; try-func) (; try-macro) (; try-hygienic) (; try-core-lib) (; try-var-args) (; try-unless) (; try-foldl) (; try-syntax) (; echo $ hole-series 162) (; try-list) (; try-map-fn) (; try-maps) (; try-str) (try-edn)
        |try-hygienic $ quote
          defn try-hygienic ()
            let
                c 2
              echo $ add-11 1 2
        |try-unless $ quote
          defn try-unless ()
            if true (println "\"true") (println "\"false")
            unless true (println "\"true") (println "\"false")
        |var-macro $ quote
          defmacro var-macro (a & xs) (echo a xs) (quote $ do)
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
                + (~ a) (~ b) (, c)
        |try-map-fn $ quote
          defn try-map-fn ()
            each
              fn (x) (echo x "\"->" $ hole-series x)
              range 1 200
            echo $ map
              fn (x) (hole-series x)
              range 1 50
        |insert-x $ quote
          defmacro insert-x (a b c)
            quote-replace $ do
              echo $ + (~ a) (~ b)
              echo $ ~@ c
        |try-list $ quote
          defn try-list ()
            let
                a $ [] 1 2 3
              echo a
              echo (prepend a 4) (append a 4)
              echo (first a) (first $ []) (last a) (last $ [])
              echo (rest a) (rest $ []) (butlast a) (butlast $ [])
              echo "\"range" (range 0) (range 1) (range 4) (range 4 5) (range 4 10)
              echo "\"slice"
                slice (range 10) (, 0 10)
                slice (range 10) (, 5 7)
              echo
                concat (range 10) (range 4)
                format-ternary-tree $ concat (range 10) (range 4)
              echo $ format-ternary-tree
                assoc-before (range 8) (, 4 22)
              echo $ format-ternary-tree
                assoc-after (range 8) (, 4 22)
              echo
                assoc (range 10) (, 4 55)
                dissoc (range 10) (, 4)
              echo (take 4 $ range 10) (drop 4 $ range 10)
        |try-var-args $ quote
          defn try-var-args () (var-fn 1 2 3 4) (var-macro a b c d)
        |try-syntax $ quote
          defn try-syntax () (echo $ syntax-add 1 2 3)
        |try-core-lib $ quote
          defn try-core-lib () (echo $ + 1 2 3)
            echo (&+ 1 2) (&- 2 1)
        |try-edn $ quote
          defn try-edn ()
            echo $ str (load-cirru-edn "\"./example/compact.cirru")
        |gen-num $ quote
          defmacro gen-num (a b c) (echo "\"expanding..." a b c) (quote $ + 1 2 3)
        |try-str $ quote
          defn try-str ()
            echo (&str-concat |a |b) (&str-concat 1 2)
            echo (str |a |b |c) (str 1 2 3)
            echo $ type-of (&str 1)
        |reload! $ quote
          defn reload! () (println "\"Reloaded...") (main!)
        |syntax-add $ quote
          defsyntax syntax-add (a b c)
            + (eval a) (eval b) (eval c)
        |var-fn $ quote
          defn var-fn (a & xs) (echo a xs)
        |try-func $ quote
          defn try-func () (echo "\"Running demo" $ demo 1 4) (show-info 1) (lib/show-info 2) (pr-str 1 "\"2" true) (; echo "\"fibo result:" $ fibo 16)
        |try-foldl $ quote
          defn try-foldl ()
            ; echo $ get ([] 1 2 3) (, 0)
            ; echo "\"foldl:" $ foldl &+ ([] 1 2 3) (, 0)
            echo $ + 1 2 3 4 (+ 5 6 7)
            ; echo $ + 1 2 3 4 5
            ; echo "\"minus" (- 1 2) (- 4 5 6) (- 100 $ - 10 1)
            ; echo "\"compare" $ foldl-compare &< ([] 1 2) (, 2)
            ; echo "\"compare" (< 1 2 3 4) (< 3 2)
            echo (* 2 3) (* 2 3 4)
            echo (/ 2 3) (/ 2 3 4)
            ; assert "\"asserting value" false
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
