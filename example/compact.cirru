
{} (:package |app)
  :configs $ {} (:init-fn |app.main/main!) (:reload-fn |app.main/reload!)
  :files $ {}
    |app.main $ {}
      :ns $ quote
        ns app.main $ :require ([] app.lib :refer $ [] show-info) ([] app.lib :as lib) ([] app.draw :as draw)
      :defs $ {}
        |try-maps $ quote
          defn try-maps ()
            echo $ {} (:a 1) (:b 2)
            let
                dict $ merge
                  {} (:a 1) (:b 2)
                  {} (:c 3) (:d 5)
              echo dict
              echo (contains? dict :a) (contains? dict :a2)
              echo $ keys dict
              echo (assoc dict :h 10) (dissoc dict :a) (dissoc dict :h)
        |try-json $ quote
          defn try-json ()
            let
                path "\"codes.json"
                data $ parse-json (read-file path)
                new-data $ ->> data
                  map $ fn (item) (echo) (echo "\"item:" $ dissoc item |children) (dissoc item |children)
              echo $ stringify-json new-data
              write-file "\"codes-new.json" (stringify-json new-data) (, )
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
            ; raise
            println "\"inserting:" $ insert-x 1 2 (3 4 5 $ + 7 8)
            echo $ macroexpand (quote $ gen-num 1 3 4)
            echo $ macroexpand
              quote $ apply + (1 2 3 4)
            echo $ macroexpand
              quote $ -> a b (c d) (e f g)
            echo $ macroexpand
              quote $ ->> a b (c d) (e f g)
            echo $ macroexpand
              quote $ cond
                  > a 10
                  , 10
                (> a 5)
                  , 5
                true 1
            echo $ let
                a 4
              cond
                  > a 10
                  , 10
                (> a 5)
                  , 5
                true 1
            echo $ macroexpand
              quote $ case a (1 "\"one") (2 "\"two") (a "\"else..")
            echo $ let
                a 3
              case a (1 "\"one") (2 "\"two") (a "\"else..")
        |main! $ quote
          defn main! () (println "\"Loaded program!") (; try-let) (; try-func) (; try-macro) (; try-hygienic) (; try-core-lib) (; try-var-args) (; try-unless) (; try-foldl) (; echo $ hole-series 162) (; try-list) (; try-map-fn) (; try-maps) (; try-str) (; try-edn) (; try-math) (; try-set) (; try-recur 0) (; try-get-in) (; try-every) (; try-fibo) (; try-json) (draw/try-canvas) (; try-atom)
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
        |try-math $ quote
          defn try-math () (echo $ sin 1) (echo $ cos 1) (echo $ floor 1.1) (echo $ ceil 1.1) (echo $ round 1.1) (echo $ pow 3 4) (echo $ mod 33 4) (echo $ sqrt 81) (echo &PI) (echo &E)
        |on-window-event $ quote
          defn on-window-event (event)
            let
                t $ get event "\"type"
              case t ("\"window-resized" $ draw/try-redraw-canvas)
                "\"mouse-button-down" $ when (&= "\"inc" $ get event "\"path")
                  reset! draw/*control-point $ let
                      p (deref draw/*control-point) (, )
                    {}
                      :x $ &+ 4 (:x p)
                      :y $ &- (:y p) (, 2)
                  draw/try-redraw-canvas
                t $ echo event
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
                &concat (range 10) (range 4)
                format-ternary-tree $ &concat (range 10) (range 4)
              echo $ format-ternary-tree
                assoc-before (range 8) (, 4 22)
              echo $ format-ternary-tree
                assoc-after (range 8) (, 4 22)
              echo
                assoc (range 10) (, 4 55)
                dissoc (range 10) (, 4)
              echo (take 4 $ range 10) (drop 4 $ range 10)
        |try-every $ quote
          defn try-every ()
            let
                data $ [] 1 2 3 4
              echo $ every?
                fn (x) (&> x 1)
                , data
              echo $ every?
                fn (x) (&> x 0)
                , data
              echo $ any?
                fn (x) (&> x 3)
                , data
              echo $ any?
                fn (x) (&> x 4)
                , data
        |try-var-args $ quote
          defn try-var-args () (var-fn 1 2 3 4) (var-macro a b c d)
        |try-get-in $ quote
          defn try-get-in ()
            let
                data $ {} (:a $ [] 1 2 3)
                b $ []
                  {} $ :a ([] 1 2 3)
              echo $ get-in data ([] :a 2)
              echo $ get-in b ([] 0 :a 2)
              echo $ get-in data ([] :x :y :z)
        |*state-a $ quote
          defatom *state-a $ {} (:count 0)
        |try-core-lib $ quote
          defn try-core-lib () (echo $ + 1 2 3)
            echo (&+ 1 2) (&- 2 1)
        |try-recur $ quote
          defn try-recur (x) (; echo "\"running" x) (; recur $ &+ x 1) (; echo $ recur-inc 0 4000)
            echo $ loop
                a 0
                b 0
              if (&< a 2000)
                do (echo a b)
                  recur (&+ a 1) (&+ b 2)
                &+ a b
        |try-atom $ quote
          defn try-atom () (echo *state-a) (echo $ deref *state-a)
            add-watch *state-a :a $ fn (a b) (echo "\"change happened:" a b)
            remove-watch *state-a :a
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
          defn reload! () (println "\"Reloaded...") (; main!) (draw/try-redraw-canvas) (; reload-atom)
        |recur-inc $ quote
          defn recur-inc (acc max-value) (; echo "\"adding to acc: " acc)
            if (&< acc max-value)
              recur (&+ acc 0.1) (, max-value)
              , acc
        |var-fn $ quote
          defn var-fn (a & xs) (echo a xs)
        |try-fibo $ quote
          defn try-fibo () (echo "\"fibo result:" $ fibo 11)
        |try-func $ quote
          defn try-func () (echo "\"Running demo" $ demo 1 4) (show-info 1) (lib/show-info 2) (pr-str 1 "\"2" true)
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
        |try-set $ quote
          defn try-set ()
            let
                data $ #{} 1 2 3 4 5 6
                d2 $ &include data 11
                d3 $ &exclude data 6
              echo data
              echo $ contains? data 1
              echo $ contains? data 18
              echo $ count data
              echo data d2 d3
              echo $ &difference (#{} 1 2 3) (#{} 1 2)
              echo $ &union (#{} 1 2 3) (#{} 1 2)
              echo $ &intersection (#{} 1 2 3) (#{} 1 2)
            echo $ include (#{} 0) (, 1 2 4)
            echo $ exclude (#{} 1 2 3 4 5) (, 1 2 4)
            echo $ difference (#{} 1 2) (#{} 2 3) (#{} 3 4)
            echo $ union (#{} 1 2) (#{} 2 3) (#{} 3 4)
            echo $ intersection (#{} 1 2 3) (#{} 2 3) (#{} 3 4)
        |reload-atom $ quote
          defn reload-atom () (println "\"handl atom changes") (echo *state-a) (echo $ deref *state-a)
            ; reset! *state-a $ {} (:count 3)
            swap! *state-a update :count $ \ &+ 4 %
            echo *state-a
            echo $ deref *state-a
      :proc $ quote ()
      :configs $ {} (:extension nil)
    |app.lib $ {}
      :ns $ quote (ns app.lib)
      :defs $ {}
        |show-info $ quote
          defn show-info (x) (echo "\"information blabla" x)
      :proc $ quote ()
      :configs $ {}
    |app.draw $ {}
      :ns $ quote (ns app.draw)
      :defs $ {}
        |try-redraw-canvas $ quote
          defn try-redraw-canvas ()
            draw-canvas $ g ({})
              {} (:type :polyline) (:from $ [] 40 40)
                :stops $ [][] (100 60) (200 200) (600 60) (500 400) (300 300)
                    :x $ deref *control-point
                    :y $ deref *control-point
                :stroke-color $ [] 200 90 80 1
              {} (:type :touch-area) (:x 100) (:y 100) (:radius 20) (:path "\"inc") (:events $ [] :touch-down)
        |try-canvas $ quote
          defn try-canvas ()
            init-canvas $ {} (:title "\"DEMO") (:width 1200) (:height 800)
            try-redraw-canvas
        |*control-point $ quote
          defatom *control-point $ {} (:x 400) (:y 400)
      :proc $ quote ()
      :configs $ {}
