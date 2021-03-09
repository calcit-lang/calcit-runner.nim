
{} (:package |app)
  :configs $ {} (:init-fn |app.main/main!) (:reload-fn |app.main/reload!) (:modules nil) (:version nil)
  :files $ {}
    |app.main $ {}
      :ns $ quote
        ns app.main $ :require
          [] app.lib :refer $ [] show-info
          [] app.lib :as lib
          [] app.draw :as draw
          [] app.lib :refer $ [] inc10
      :defs $ {}
        |try-json $ quote
          defn try-json () $ let
              path "\"codes.json"
              data $ parse-json (read-file path)
              new-data $ ->> data
                map $ fn (item) (echo)
                  echo "\"item:" $ dissoc item |children
                  dissoc item |children
            echo $ stringify-json new-data
            write-file "\"codes-new.json" (stringify-json new-data)
        |main! $ quote
          defn main! () (println "\"Loaded program!") (; try-func) (; try-hygienic) (; try-var-args) (; try-edn) (; try-json) (; echo [,])
            ; echo $ fn (a) 1
            ; draw/try-canvas
            try-atom
            try-atom
            try-thunk
            try-thunk
            ; try-timeout
            load-console-formatter!
            js/console.log "\"Primatives" "\"string" 'symbol :keyword
            js/console.log "\"Map" $ {} (:a "\"demo")
              :b $ [] "\"demo"
            js/console.log "\"List"
              [] 1 2 3 4 $ [] 5 6 7 ([] 8 9)
              []
                {} $ :name "\"A"
                {} (:name "\"A") (:size 40)
                {} (:name "\"A") (:weight 10)
                , 1 2 $ []
            let
                P $ new-record 'P :name :age :home :tags
              js/console.log "\"Record" P $ %{} P (:name "\"Re") (:age 10) (:home "\"Shanghai")
                :tags $ #{} :lang :web
            js/console.log "\"Set" $ #{} 1 2 3 4
            js/console.log *state-a
        |try-hygienic $ quote
          defn try-hygienic () $ let
              c 2
            echo $ add-11 1 2
        |var-macro $ quote
          defmacro var-macro (a & xs) (echo a xs)
            quote $ do
        |on-window-event $ quote
          defn on-window-event (event)
            let
                t $ get event "\"type"
              case t
                "\"window-resized" $ draw/try-redraw-canvas
                "\"mouse-button-down" $ when
                  &= "\"inc" $ get event "\"path"
                  reset! draw/*control-point $ let
                      p (deref draw/*control-point)
                    {}
                      :x $ &+ 4 (:x p)
                      :y $ &- (:y p) 2
                  draw/try-redraw-canvas
                t $ echo event
        |add-11 $ quote
          defmacro add-11 (a b)
            let
                c 11
              echo "\"internal c:" a b c
              quote-replace $ do (echo "\"c is:" c)
                + (~ a) (~ b) c
        |try-thunk $ quote
          defn try-thunk () $ echo "\"running thunk with data:" demo-thunk-data
        |try-var-args $ quote
          defn try-var-args () (var-fn 1 2 3 4) (var-macro a b c d)
        |*state-a $ quote
          defatom *state-a $ do (echo "\"initilizing state a")
            {} $ :count 0
        |try-atom $ quote
          defn try-atom () (echo *state-a)
            echo $ deref *state-a
            swap! *state-a update :count inc
            add-watch *state-a :a $ fn (a b) (echo "\"change happened:" a b)
            remove-watch *state-a :a
        |try-edn $ quote
          defn try-edn () $ echo
            str $ load-cirru-edn "\"./example/compact.cirru"
        |try-timeout $ quote
          defn try-timeout () (echo "\"timeout")
            &doseq
              idx $ range 40
              timeout-call (* idx 80)
                fn () $ echo "\"finished:" idx
            echo "\"next"
        |gen-num $ quote
          defmacro gen-num (a b c) (echo "\"expanding..." a b c)
            quote $ + 1 2 3
        |reload! $ quote
          defn reload! ()
            println "\"Reloaded..." $ inc10 4
            ; main!
            draw/try-redraw-canvas
            ; reload-atom
        |demo-thunk-data $ quote
          def demo-thunk-data $ do (echo "\"inside a chunk") (+ 1 2 3 4)
        |var-fn $ quote
          defn var-fn (a & xs) (echo a xs)
        |on-error $ quote
          defn on-error (message) (draw-error-message message)
        |try-func $ quote
          defn try-func ()
            echo "\"Running demo" $ demo 1 4
            show-info 1
            lib/show-info 2
            println $ pr-str 1 "\"2" "\"3 4" true
              {} $ :a "\"1"
            println 1 "\"2" "\"3 4" true $ {} (:a "\"1")
        |demo $ quote
          defn demo (x y)
            echo "\"adding:" x y "\"result is" $ + x y
        |reload-atom $ quote
          defn reload-atom () (println "\"handl atom changes") (echo *state-a)
            echo $ deref *state-a
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
        |inc10 $ quote
          defn inc10 (x) (+ x 2)
      :proc $ quote ()
      :configs $ {}
    |app.draw $ {}
      :ns $ quote (ns app.draw)
      :defs $ {}
        |try-redraw-canvas $ quote
          defn try-redraw-canvas () $ draw-canvas
            g ({})
              {} (:type :polyline)
                :from $ [] 40 40
                :stops $ [][] (100 60) (200 200) (600 60) (500 400) (300 300)
                    :x $ deref *control-point
                    :y $ deref *control-point
                :line-color $ [] 200 90 80 1
              {} (:type :touch-area) (:x 100) (:y 100) (:radius 20) (:path "\"inc")
                :events $ [] :touch-down
                :action :demo
        |try-canvas $ quote
          defn try-canvas () (echo "\"init" "\"canvas")
            init-canvas $ {} (:title "\"DEMO") (:width 1200) (:height 800)
            try-redraw-canvas
        |*control-point $ quote
          defatom *control-point $ {} (:x 400) (:y 400)
        |g $ quote
          defn g (props & children)
            merge props $ {} (:type :group) (:children children)
      :proc $ quote ()
      :configs $ {}
