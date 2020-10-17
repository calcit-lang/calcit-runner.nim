
{} (:package |app)
  :configs $ {} (:init-fn |app.main/main!) (:reload-fn |app.main/reload!)
  :files $ {}
    |app.main $ {}
      :ns $ quote
        ns app.main $ :require
      :defs $ {}

        |test-cond $ quote
          defn test-cond ()
            let
                compare-x $ fn (x)
                  cond
                    (&> x 10) "|>10"
                    (&> x 5) "|>5"
                    true "|<=5"
              assert "|try cond" $ &= (compare-x 11) "|>10"

        |test-raw-cond $ quote
          defn test-raw-cond (x)
            cond
              (&> x 10) "|>10"
              (&> x 5) "|>5"
              true "|<=5"

        |test-case $ quote
          |defn test-case ()
            let
                detect-x $ fn (x)
                  case x
                    1 "|one"
                    2 "|two"
                    x "|else"
              assert "|try case" $ &= (detect-x 1) "|one"

        |main! $ quote
          defn main! ()
            echo $ test-cond

      :proc $ quote ()
      :configs $ {} (:extension nil)
