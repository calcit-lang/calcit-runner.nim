
{} (:package |app)
  :configs $ {} (:init-fn |app.main/main!) (:reload-fn |app.main/reload!)
  :files $ {}
    |app.main $ {}
      :ns $ quote
        ns app.main $ :require ([] app.lib :refer $ [] show-info) ([] app.lib :as lib)
      :defs $ {}
        |main! $ quote
          defn main! () (println "\"Loaded program!") (echo "\"Running demo" $ demo 1 4) (show-info 1) (lib/show-info 2) (echo "\"fibo result:" $ fibo 16)
        |demo $ quote
          defn demo (x y) (echo "\"adding:" x y "\"result is" $ + x y)
        |reload! $ quote
          defn reload! ()
            do (echo 1) (echo 2 3)
            let
                a $ + 10 10
              echo "\"reloaded... 7" a
            echo $ + 1 2 3 1
            main!
        |fibo $ quote
          defn fibo (x)
            if (< x 2) (, 1)
              + (fibo $ - x 1) (fibo $ - x 2)
      :proc $ quote ()
      :configs $ {} (:extension nil)
    |app.lib $ {}
      :ns $ quote (ns app.lib)
      :defs $ {}
        |show-info $ quote
          defn show-info (x) (echo "\"information blabla" x)
      :proc $ quote ()
      :configs $ {}
