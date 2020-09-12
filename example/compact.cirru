
{} (:package |app)
  :configs $ {} (:init-fn |app.main/main!) (:reload-fn |app.main/reload!)
  :files $ {}
    |app.main $ {}
      :ns $ quote (ns app.main)
      :defs $ {}
        |main! $ quote
          defn main! ()
            echo $ + 1 2 (+ 4 5 9)
            println "\"Loaded program!"
        |demo $ quote
          defn demo () (echo "\"demo 4")
        |reload! $ quote
          defn reload! () (echo "\"reloaded... 7")
      :proc $ quote ()
      :configs $ {}
