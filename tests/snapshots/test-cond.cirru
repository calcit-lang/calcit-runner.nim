
{} (:package |test-cond)
  :configs $ {} (:init-fn |test-cond.main/main!) (:reload-fn |test-cond.main/reload!)
  :files $ {}
    |test-cond.main $ {}
      :ns $ quote
        ns test-cond.main $ :require
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
              assert "|try cond" $ &= (compare-x 10) "|>5"
              assert "|try cond" $ &= (compare-x 6) "|>5"
              assert "|try cond" $ &= (compare-x 4) "|<=5"

        |test-case $ quote
          defn test-case ()
            let
                detect-x $ fn (x)
                  case x
                    1 "|one"
                    2 "|two"
                    x "|else"
              assert "|try case" $ &= (detect-x 1) "|one"
              assert "|try case" $ &= (detect-x 2) "|two"
              assert "|try case" $ &= (detect-x 3) "|else"

        |log-title $ quote
          defn log-title (title)
            echo
            echo title
            echo

        |main! $ quote
          defn main! ()
            log-title "|Testing cond"
            test-cond

            test-case
            , true

      :proc $ quote ()
      :configs $ {} (:extension nil)
