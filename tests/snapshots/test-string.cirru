
{} (:package |app)
  :configs $ {} (:init-fn |app.main/main!) (:reload-fn |app.main/reload!)
  :files $ {}
    |app.main $ {}
      :ns $ quote
        ns app.main $ :require
      :defs $ {}

        |test-str $ quote
          defn test-str ()
            assert "|string concat" $ = (&str-concat |a |b) |ab
            assert "|string concat" $ = (&str-concat 1 2) |12
            assert "|string concat" $ = (str |a |b |c) |abc
            assert "|string concat" $ = (str 1 2 3) |123
            assert |convert $ = (type-of (&str 1)) :string
            assert "|string replace" $ =
              replace "|this is a" |is |IS
              , "|thIS IS a"
            assert "|string splitting" $ =
              split "|a,b,c" "|,"
              [] |a |b |c
            assert "|string splitting" $ =
              split-lines "|a\nb\nc"
              [] |a |b |c
            assert= 4
              count |good
            assert= |56789 $ substr |0123456789 5
            assert= |567 $ substr |0123456789 5 8
            assert= | $ substr |0123456789 10
            assert= | $ substr |0123456789 9 1

        |test-contains $ quote
          fn ()
            assert= true $ contains? |abc |abc
            assert= false $ contains? |abd |abc

            assert= 3 $ str-find |0123456 |3
            assert= 3 $ str-find |0123456 |34
            assert= 0 $ str-find |0123456 |01
            assert= 4 $ str-find |0123456 |456
            assert= -1 $ str-find |0123456 |98

            assert= true $ starts-with? |01234 |0
            assert= true $ starts-with? |01234 |01
            assert= false $ starts-with? |01234 |12

            assert= true $ ends-with? |01234 |34
            assert= true $ ends-with? |01234 |4
            assert= false $ ends-with? |01234 |23

        |test-parse $ quote
          fn ()
            assert= 0 $ parse-float |0

        |test-trim $ quote
          fn ()
            assert= | $ trim "|    "
            assert= |1 $ trim "|  1  "

            assert= | $ trim "|______" |_
            assert= |1 $ trim "|__1__" |_

        |log-title $ quote
          defn log-title (title)
            echo
            echo title
            echo

        |test-format $ quote
          fn ()
            log-title "|Testing format"

            assert= |1.2346 $ format-number 1.23456789 4
            assert= |1.235 $ format-number 1.23456789 3
            assert= |1.23 $ format-number 1.23456789 2
            assert= |1.2 $ format-number 1.23456789 1

        |test-char $ quote
          fn ()
            log-title "|Test char"

            echo "|char:" $ get-char-code |a

        |main! $ quote
          defn main! ()
            log-title "|Testing str"
            test-str

            log-title "|Testing contains"
            test-contains

            log-title "|Testing parse"
            test-parse

            log-title "|Testing trim"
            test-trim

            test-format

            test-char

            do true

      :proc $ quote ()
      :configs $ {} (:extension nil)
