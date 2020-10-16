
{} (:package |app)
  :configs $ {} (:init-fn |app.main/main!) (:reload-fn |app.main/reload!)
  :files $ {}
    |app.main $ {}
      :ns $ quote
        ns app.main $ :require
      :defs $ {}
        |main! $ quote
          defn main! () (println "\"Loaded program!") (try-fibo)

        |try-fibo $ quote
          defn try-fibo ()
            let
                n 12
              echo "\"fibo result:" n $ fibo n

        |fibo $ quote
          defn fibo (x)
            if (< x 2) (, 1)
              + (fibo $ - x 1) (fibo $ - x 2)

      :proc $ quote ()
      :configs $ {} (:extension nil)
