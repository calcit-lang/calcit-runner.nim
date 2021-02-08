
{} (:package |test-cond)
  :configs $ {} (:init-fn |test-cond.main/main!) (:reload-fn |test-cond.main/reload!)
    :modules $ |./util.cirru
  :files $ {}
    |test-cond.main $ {}
      :ns $ quote
        ns test-cond.main $ :require
          [] util.core :refer $ [] inside-nim:
      :defs $ {}

        |test-cond $ quote
          defn test-cond ()
            let
                compare-x $ fn (x)
                  cond
                    (&> x 10) "|>10"
                    (&> x 5) "|>5"
                    true "|<=5"
              assert= (compare-x 11) "|>10"
              assert= (compare-x 10) "|>5"
              assert= (compare-x 6) "|>5"
              assert= (compare-x 4) "|<=5"

        |test-case $ quote
          defn test-case ()
            let
                detect-x $ fn (x)
                  case x
                    1 "|one"
                    2 "|two"
                    x "|else"
              assert= (detect-x 1) "|one"
              assert= (detect-x 2) "|two"
              assert= (detect-x 3) "|else"

            inside-nim:
              assert=
                macroexpand $ quote
                  case-default x |nothing
                    1 |one
                    2 |two
                quote $ &let (v__2 x)
                  &let (default__3 |nothing)
                    &case v__2 default__3 (1 |one) (2 |two)

            &let
              detect-x $ fn (x)
                case-default x |nothing
                  1 |one
                  2 |two
              assert= (detect-x 0) |nothing
              assert= (detect-x 1) |one
              assert= (detect-x 2) |two

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
