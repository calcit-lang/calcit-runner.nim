
{} (:package |app)
  :configs $ {} (:init-fn |app.main/main!) (:reload-fn |app.main/reload!)
  :files $ {}
    |app.main $ {}
      :ns $ quote (ns app.main)
      :defs $ {}
        |main! $ quote
          defn main! () (echo $ + 1 2) (println "\"Loaded program!") (echo "\"Running demo" $ demo 1 4)
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
      :proc $ quote ()
      :configs $ {}
