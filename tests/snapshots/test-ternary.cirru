
{} (:package |app)
  :configs $ {} (:init-fn |app.main/main!) (:reload-fn |app.main/reload!)
  :files $ {}
    |app.main $ {}
      :ns $ quote
        ns app.main $ :require
      :defs $ {}

        |log-title $ quote
          defn log-title (title)
            echo
            echo title
            echo

        |test-ternary $ quote
          fn ()
            assert= &1 &1
            assert= &1.3 &1.3
            assert= (&+ &1 &1) &19
            assert= (+ &1 &1 &1) &15
            assert= (+ &1 &1 &1 &1) &11
            assert= (&- &44 &6) &466
            assert= (ternary->point &33) ([] 4 0)
            assert= (ternary->point &66) ([] -4 4)
            assert= (dual-balanced-ternary 4 4) &88

            assert= (round &3.333) &3
            assert= (round &3.333 0) &3
            assert= (round &3.333 1) &3.3
            assert= (round &3.333 2) &3.33

        |main! $ quote
          defn main! ()
            log-title "|Testing ternary"
            test-ternary

            do true

      :proc $ quote ()
      :configs $ {} (:extension nil)
