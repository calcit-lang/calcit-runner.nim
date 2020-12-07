
{} (:package |app)
  :configs $ {} (:init-fn |app.main/main!) (:reload-fn |app.main/reload!)
  :files $ {}
    |app.main $ {}
      :ns $ quote
        ns app.main $ :require
      :defs $ {}
        |test-numbers $ quote
          defn test-numbers ()
            assert "|simple add" $ = 3 (+ 1 2)
            assert |add $ = 10 (+ 1 2 3 4)
            assert |minus $ = 4 (- 10 1 2 3)
            assert |mutiply $ = 24 (* 1 2 3 4)
            assert |divide $ = 15 (/ 360 2 3 4)
            assert |littler $ < 1 2 3 4 5
            assert |larger $ > 10 8 6 4
            assert |empty $ empty? nil
            assert "|empty vector" $ empty? ([])

            assert "|rand" $ <= 0 (rand) 100
            assert "|rand" $ <= 0 (rand 10) 10
            assert "|rand" $ <= 20 (rand 20 30) 30

            assert "|rand-int" $ <= 0 (rand-int) 100
            assert "|rand-int" $ <= 0 (rand-int 10) 10
            assert "|rand-int" $ <= 20 (rand-int 20 30) 30

            do true

        |log-title $ quote
          defn log-title (title)
            echo
            echo title
            echo

        |test-math $ quote
          defn test-math ()
            echo "|sin 1" $ sin 1
            echo "|cos 1" $ cos 1
            assert "|sin and cos" $ = 1 $ + (pow (sin 1) 2) (pow (cos 1) 2)
            assert |floor $ = 1 $ floor 1.1
            assert |ceil $ = 2 $ ceil 1.1
            assert |round $ = 1 $ round 1.1
            assert |round $ = 2 $ round 1.8
            assert |pow $ = 81 $ pow 3 4
            assert |mod $ = 1 $ mod 33 4
            assert |sqrt $ = 9 $ sqrt 81
            echo |PI &PI
            echo |E &E

        |test-compare $ quote
          defn test-compare ()
            assert "|find max" $ = 4 $ max $ [] 1 2 3 4
            assert "|find min" $ = 1 $ min $ [] 1 2 3 4

            assert "|not equal" $ /= 1 2

        |test-hex $ quote
          fn ()
            log-title "|Testing hex"

            assert= 16 0x10
            assert= 15 0xf

        |main! $ quote
          defn main! ()
            log-title "|Testing numbers"
            test-numbers

            log-title "|Testing math"
            test-math

            log-title "|Testing compare"
            test-compare

            test-hex

            do true

      :proc $ quote ()
      :configs $ {} (:extension nil)
