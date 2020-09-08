
{} (:package |app)
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
      :proc $ quote ()
      :configs $ {}
