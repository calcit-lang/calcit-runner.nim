

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

        |test-json $ quote
          fn ()
            assert=
              parse-json "|{\"a\": [1, 2], \":b\": 3}"
              {}
                |a $ [] 1 2
                :b 3
            &let
              data $ {}
                |a 1
                :b 2
                :c :k
              assert= data $ parse-json $ stringify-json data true
            &let
              data $ {}
                |a 1
                :b 2
                :c :k

              assert=
                parse-json $ stringify-json data
                {}
                  |a 1
                  |b 2
                  |c |k

        |main! $ quote
          defn main! ()
            log-title "|Testing json"
            test-json

            do true

      :proc $ quote ()
      :configs $ {} (:extension nil)
