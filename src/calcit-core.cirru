
{} (:package |calcit)
  :configs $ {}
  :files $ {}
    |calcit.core $ {}
      :ns $ quote
        ns calcit.core $ :require
      :defs $ {}
        |unless $ quote
          defmacro unless (cond true-branch false-branch)
            quote-replace $ if ~cond ~false-branch ~true-branch

        |/= $ quote
          defn /= (x y) $ not $ &= x y

        |&<= $ quote
          defn &<= (a b)
            &or (&< a b) (&= a b)

        |&>= $ quote
          defn &>= (a b)
            &or (&> a b) (&= a b)

        |first $ quote
          defn first (xs) (get xs 0)

        |when $ quote
          defmacro when (condition & body)
            quote-replace $ if ~condition (do ~@body)

        |+ $ quote
          defn + (x & ys) $ reduce &+ x ys

        |- $ quote
          defn - (x & ys) $ reduce &- x ys

        |* $ quote
          defn * (x & ys) $ reduce &* x ys

        |/ $ quote
          defn / (x & ys) $ reduce &/ x ys

        |foldl-compare $ quote
          defn foldl-compare (f acc xs)
            if (empty? xs) true
              if (f acc (first xs))
                recur f (first xs) (rest xs)
                , false

        |foldl' $ quote
          defn foldl' (f acc xs)
            if (empty? xs) acc
              recur f (f acc (first xs)) (rest xs)

        |< $ quote
          defn < (x & ys) $ foldl-compare &< x ys

        |> $ quote
          defn > (x & ys) $ foldl-compare &> x ys

        |= $ quote
          defn = (x & ys) $ foldl-compare &= x ys

        |>= $ quote
          defn >= (x & ys) $ foldl-compare &>= x ys

        |<= $ quote
          defn <= (x & ys) $ foldl-compare &<= x ys

        |apply $ quote
          defn apply (f args) $ f & args

        |apply-args $ quote
          defn apply-args (args f) $ f & args

        |list? $ quote
          defn list? (x) $ &= (type-of x) :list

        |map? $ quote
          defn map? (x) $ &= (type-of x) :map

        |number? $ quote
          defn number? (x) $ &= (type-of x) :number

        |string? $ quote
          defn string? (x) $ &= (type-of x) :string

        |symbol? $ quote
          defn symbol? (x) $ &= (type-of x) :symbol

        |keyword? $ quote
          defn keyword? (x) $ &= (type-of x) :keyword

        |bool? $ quote
          defn bool? (x) $ &= (type-of x) :bool

        |nil? $ quote
          defn nil? (x) $ &= (type-of x) :nil

        |macro? $ quote
          defn macro? (x) $ &= (type-of x) :macro

        |set? $ quote
          defn set? (x) $ &= (type-of x) :set

        |fn? $ quote
          defn fn? (x)
            &or
              &= (type-of x) :fn
              &= (type-of x) :proc

        |each $ quote
          defn each (f xs)
            if (not (empty? xs))
              do
                f (first xs)
                recur f (rest xs)

        |map $ quote
          defn map (f xs)
            reduce
              fn (acc x) $ append acc (f x)
              []
              , xs

        |take $ quote
          defn take (n xs)
            if (= n (count xs)) xs
              slice xs 0 n

        |drop $ quote
          defn drop (n xs)
            slice xs n (count xs)

        |str $ quote
          defn str (& xs)
            reduce
              fn (acc item) $ &str-concat acc item
              , | xs

        |include $ quote
          defn include (base & xs)
            reduce
              fn (acc item) $ &include acc item
              , base xs

        |exclude $ quote
          defn exclude (base & xs)
            reduce
              fn (acc item) $ &exclude acc item
              , base xs

        |difference $ quote
          defn difference (base & xs)
            reduce
              fn (acc item) $ &difference acc item
              , base xs

        |union $ quote
          defn union (base & xs)
            reduce
              fn (acc item) $ &union acc item
              , base xs

        |intersection $ quote
          defn intersection (base & xs)
            reduce
              fn (acc item) $ &intersection acc item
              , base xs

        |index-of $ quote
          defn index-of (xs0 item)
            apply-args
              [] 0 xs0
              fn (idx xs)
                if (empty? xs) nil
                  if (&= item (first xs)) idx
                    recur (&+ 1 idx) (rest xs)

        |find-index $ quote
          defn find-index (f xs0)
            apply-args
              [] 0 xs0
              fn (idx xs)
                if (empty? xs) nil
                  if (f (first xs)) idx
                    recur (&+ 1 idx) f (rest xs)

        |find $ quote
          defn find (f xs)
            &let
              idx (&find-index 0 f xs)
              if (nil? idx) nil (get xs idx)

        |-> $ quote
          defmacro -> (base & xs)
            if (empty? xs)
              quote-replace ~base
              &let
                x0 (first xs)
                if (list? x0)
                  recur
                    &concat ([] (first x0) base) (rest x0)
                    , & (rest xs)
                  recur ([] x0 base) & (rest xs)

        |->> $ quote
          defmacro ->> (base & xs)
            if (empty? xs)
              quote-replace ~base
              &let
                x0 (first xs)
                if (list? x0)
                  recur (append x0 base) & (rest xs)
                  recur ([] x0 base) & (rest xs)

        |cond $ quote
          defmacro cond (pair & else)
            assert "|expects a pair"
              &and (list? pair) (&= 2 (count pair))
            let
                expr $ first pair
                branch $ last pair
              quote-replace
                if ~expr ~branch
                  ~ $ if (empty? else) nil
                    quote-replace
                      cond
                        ~ $ first else
                        , &
                        ~ $ rest else

        |&case $ quote
          defmacro &case (item pattern & others)
            assert "|expects pattern in a pair"
              &and (list? pattern) (&= 2 (count pattern))
            let
                x $ first pattern
                branch $ last pattern
              quote-replace
                if (&= ~item ~x) ~branch
                  ~ $ if (empty? others) nil
                    quote-replace
                      &case ~item ~@others

        |case $ quote
          defmacro case (item & patterns)
            &let
              v (gensym |v)
              quote-replace
                &let
                  ~v ~item
                  &case ~v ~@patterns

        |get-in $ quote
          defn get-in (base path)
            assert "|expects path in a list" (list? path)
            cond
              (nil? base) nil
              (empty? path) base
              true
                recur
                  get base (first path)
                  rest path

        |&max $ quote
          defn &max (a b)
            assert "|expects numbers for &max" $ &and (number? a) (number? b)
            if (&> a b) a b

        |&min $ quote
          defn &min (a b)
            assert "|expects numbers for &min" $ &and (number? a) (number? b)
            if (&< a b) a b

        |max $ quote
          defn max (xs)
            if (empty? xs) nil
              reduce
                fn (acc x) (&max acc x)
                first xs
                rest xs

        |min $ quote
          defn min (xs)
            if (empty? xs) nil
              reduce
                fn (acc x) (&min acc x)
                first xs
                rest xs

        |every? $ quote
          defn every? (f xs)
            if (empty? xs) true
              if (f (first xs))
                recur f (rest xs)
                , false

        |any? $ quote
          defn any? (f xs)
            if (empty? xs) false
              if (f (first xs)) true
                recur f (rest xs)

        |concat $ quote
          defn concat (& xs)
            if (empty? xs)
              []
              if (&= 1 (count xs)) (first xs)
                recur (&concat (get xs 0) (get xs 1)) & (slice xs 2)

        |mapcat $ quote
          defn mapcat (f xs)
            concat & $ map f xs

        |merge $ quote
          defn merge (x0 & xs)
            reduce &merge x0 xs

        |identity $ quote
          defn identity (x) x

        |map-indexed $ quote
          defn map-indexed (f xs)
            apply-args
              [] ([]) 0 xs
              fn (acc idx ys)
                if (empty? ys) acc
                  recur
                    append acc (f idx (first ys))
                    &+ idx 1
                    rest ys

        |filter $ quote
          defn filter (f xs)
            reduce
              fn (acc x)
                if (f x) (append acc x) acc
              []
              , xs

        |filter-not $ quote
          defn filter-not (f xs)
            reduce
              fn (acc x)
                unless (f x) (append acc x) acc
              []
              , xs

        |pairs-map $ quote
          defn pairs-map (xs)
            reduce
              fn (acc pair)
                assert "|expects pair for pairs-map"
                  &and (list? pair)
                    &= 2 (count pair)
                assoc acc (first pair) (last pair)
              {}
              , xs

        |some? $ quote
          defn some? (x) $ not $ nil? x

        |zipmap $ quote
          defn zipmap (xs0 ys0)
            apply-args
              [] ({})xs0 ys0
              fn (acc xs ys)
                if
                  &or (empty? xs) (empty? ys)
                  , acc
                  recur
                    assoc acc (first xs) (first ys)
                    rest xs
                    rest ys

        |rand-nth $ quote
          defn rand-nth (xs)
            if (empty? xs) nil
              get xs $ rand-int $ &- (count xs) 1

        |contains-symbol? $ quote
          defn contains-symbol? (xs y)
            if (list? xs)
              apply-args
                [] xs
                fn (body)
                  if (empty? body) false
                    if
                      contains-symbol? (first body) y
                      , true
                      recur (rest body)
              &= xs y

        |\ $ quote
          defmacro \ (& xs)
            if (contains-symbol? xs '%2)
              quote-replace $ fn (% %2) ~xs
              quote-replace $ fn (%) ~xs

        |has-index? $ quote
          defn has-index? (xs idx)
            assert "|expects a list" (list? xs)
            assert "|expects list key to be a number" (number? idx)
            assert "|expects list key to be an integer" (&= idx (floor idx))
            &and
              &> idx 0
              &< idx (count xs)

        |update $ quote
          defn update (x k f)
            cond
              (list? x)
                if (has-index? x k)
                  assoc x k $ f (get x k)
                  , x
              (map? x)
                if (contains? x k)
                  assoc x k $ f (get x k)
                  , x
              true
                raise $ &str "|Cannot update key on item: " x

        |group-by $ quote
          defn group-by (f xs0)
            apply-args
              [] ({}) xs0
              fn (acc xs)
                if (empty? xs) acc
                  let
                      x0 $ first xs
                      key $ f x0
                    recur
                      if (contains? acc key)
                        update acc key $ \ append % x0
                        assoc acc key $ [] x0
                      rest xs

        |keys $ quote
          defn keys (x)
            map first (to-pairs x)

        |vals $ quote
          defn vals (x)
            map last (to-pairs x)

        |frequencies $ quote
          defn frequencies (xs0)
            assert "|expects a list for frequencies" (list? xs0)
            apply-args
              [] ({}) xs0
              fn (acc xs)
                &let
                  x0 (first xs)
                  if (empty? xs) acc
                    recur
                      if (contains? acc (first xs))
                        update acc (first xs) (\ &+ % 1)
                        assoc acc (first xs) 1
                      rest xs

        |section-by $ quote
          defn section-by (n xs0)
            apply-args
              [] ([]) xs0
              fn (acc xs)
                if (&<= (count xs) n)
                  append acc xs
                  recur
                    append acc (take n xs)
                    drop n xs

        |[][] $ quote
          defmacro [][] (& xs)
            &let
              items $ map
                fn (ys) $ quote-replace $ [] ~@ys
                , xs
              quote-replace $ [] ~@items

        |{} $ quote
          defmacro {} (& xs)
            &let
              ys $ map
                fn (zs)
                  quote-replace ([] ~@zs)
                , xs
              quote-replace $ &{} ~@ys

        |fn $ quote
          defmacro fn (args & body)
            quote-replace $ defn f% ~args ~@body

        |assert= $ quote
          defmacro assert= (a b)
            let
                va $ gensym |va
                vb $ gensym |vb
              quote-replace
                let
                    ~va ~a
                    ~vb ~b
                  if (/= ~va ~vb)
                    do
                      echo
                      echo "|Left: " ~va
                      echo "|      " $ quote ~a
                      echo "|Right:" ~vb
                      echo "|      " $ quote ~b
                      raise "|Not equal!"

        |swap! $ quote
          defmacro swap! (a f & args)
            quote-replace
              reset! ~a
                ~f (deref ~a) ~@args

        |assoc-in $ quote
          defn assoc-in (data path v)
            if (empty? path) v
              let
                  p0 $ first path
                  d $ either data $ &{}
                assoc d p0
                  assoc-in (get d p0) (rest path) v

        |update-in $ quote
          defn update-in (data path f)
            if (empty? path)
              f data
              &let
                p0 $ first path
                assoc data p0
                  update-in (get data p0) (rest path) f

        |dissoc-in $ quote
          defn dissoc-in (data path)
            cond
              (empty? path) nil
              (&= 1 (count path))
                dissoc data (first path)
              true
                &let
                  p0 $ first path
                  assoc data p0
                    dissoc-in (get data p0) (rest path)

        |inc $ quote
          defn inc (x) $ &+ x 1

        |dec $ quote
          defn dec (x) $ &- x 1

        |starts-with? $ quote
          defn starts-with? (x y)
            &= 0 (str-find x y)

        |ends-with? $ quote
          defn ends-with? (x y)
            &=
              &- (count x) (count y)
              str-find x y

        |loop $ quote
          defmacro loop (pairs & body)
            assert "|expects pairs in loop" (list? pairs)
            assert "|expects pairs in pairs in loop"
              every?
                defn detect-pairs? (x)
                  &and (list? x)
                    &= 2 (count x)
                , pairs
            let
                args $ map first pairs
                values $ map last pairs
              assert "|loop requires symbols in pairs" (every? symbol? args)
              quote-replace
                apply
                  defn generated-loop ~args ~@body
                  [] ~@values

        |let $ quote
          defmacro let (pairs & body)
            assert "|expects pairs in list for let" (list? pairs)
            if (&= 1 (count pairs))
              quote-replace
                &let
                  ~ $ first pairs
                  ~@ body
              if (empty? pairs)
                quote-replace $ do ~@body
                quote-replace
                  &let
                    ~ $ first pairs
                    let
                      ~ $ rest pairs
                      ~@ body

        |let-> $ quote
          defmacro let-> (& body)
            if (empty? body) (quote nil)
              if (&= 1 (count body))
                do
                  assert  "|unexpected let in last item of body" (/= 'let (first body))
                  first body
                &let
                  target $ first body
                  if (&= 'let (first target))
                    quote-replace
                      &let
                        ~ $ rest $ first body
                        let->
                          ~@ $ rest body
                    quote-replace
                      do
                        ~ $ first body
                        let->
                          ~@ $ rest body

        |[,] $ quote
          defmacro [,] (& body)
            &let
              xs $ filter
                fn (x) (/= x ',)
                , body
              quote-replace $ [] ~@xs

        |assert $ quote
          defmacro assert (message xs)
            if
              &and (string? xs) (not (string? message))
              quote-replace $ assert ~xs ~message
              quote-replace
                do
                  if (not (string? ~message))
                    raise "|expects 1st argument to be string"
                  if ~xs nil
                    do
                      echo "|Failed assertion:" (quote ~xs)
                      raise
                        ~ $ &str-concat message (quote ~xs)

        |println $ quote
          defn println (& xs)
            print & xs
            print "|\n"

        |echo $ quote
          def echo println

        |join-str $ quote
          defn join-str (sep xs0)
            apply-args
              [] | xs0 true
              fn (acc xs beginning?)
                if (empty? xs) acc
                  recur
                    &str-concat
                      if beginning? acc $ &str-concat acc sep
                      first xs
                    rest xs
                    , false

        |join $ quote
          defn join (sep xs0)
            apply-args
              [] ([]) xs0 true
              fn (acc xs beginning?)
                if (empty? xs) acc
                  recur
                    append
                      if beginning? acc (append acc sep)
                      first xs
                    rest xs
                    , false

        |repeat $ quote
          defn quote (n0 x)
            apply-args
              [] ([]) n0
              fn (acc n)
                if (&<= n 0) acc
                  recur (append acc x) (&- n 1)

        |interleave $ quote
          defn interleave (xs0 ys0)
            apply-args
              [] ([]) xs0 ys0
              fn (acc xs ys)
                if
                  &or (empty? xs) (empty? ys)
                  , acc
                  recur
                    -> acc (append (first xs)) (append (first ys))
                    rest xs
                    rest ys

        |map-kv $ quote
          defn map-kv (f dict)
            assert "|expects a map" (map? dict)
            ->> dict
              to-pairs
              map $ fn (pair)
                f (first pair) (last pair)

        |either $ quote
          defmacro either (x y)
            quote-replace $ if (nil? ~x) ~y ~x

        |def $ quote
          defmacro def (name x) x

        |and $ quote
          defmacro and (item & xs)
            if (empty? xs) item
              quote-replace
                if ~item
                  and
                    ~ $ first xs
                    ~@ $ rest xs
                  , false

        |or $ quote
          defmacro or (item & xs)
            if (empty? xs) item
              quote-replace
                if ~item true
                  or
                    ~ $ first xs
                    ~@ $ rest xs

        |with-log $ quote
          defmacro with-log (x)
            &let
              v $ gensym |v
              quote-replace
                &let
                  ~v ~x
                  echo (quote ~x) |=> ~v
                  ~ v

        |{,} $ quote
          defmacro {,} (& body)
            &let
              xs $ filter
                fn (x) (/= x ',)
                , body
              quote-replace
                pairs-map $ section-by 2 ([] ~@xs)

        |&doseq $ quote
          defmacro &doseq (pair & body)
            assert "|doseq expects a pair"
              &and (list? pair) (&= 2 (count pair))
            let
                name $ first pair
                xs0 $ last pair
              quote-replace
                apply
                  defn doseq-fn% (xs)
                    if (empty? xs) nil
                      &let
                        ~name $ first xs
                        ~@ body
                        recur $ rest xs
                  [] ~xs0

        |with-cpu-time $ quote
          defmacro with-cpu-time (x)
            let
                started $ gensym |started
                v $ gensym |v
              quote-replace
                let
                    ~started (cpu-time)
                    ~v ~x
                  echo "|[cpu-time]" (quote ~x) |=>
                    format-number
                      &* 1000 (&- (cpu-time) ~started)
                      , 3
                    , |ms
                  ~ v

        |call-with-log $ quote
          defmacro call-with-log (f & xs)
            let
                v $ gensym |v
                args-value $ gensym |args-value
              quote-replace
                let
                    ~args-value $ [] ~@xs
                    ~v $ ~f & ~args-value
                  echo "|call:"
                    quote ('call-with-log ~f ~@xs)
                    , |=> ~v
                  echo "|f:   " ~f
                  echo "|args:" ~args-value
                  ~ v

        |defn-with-log $ quote
          defmacro defn-with-log (f-name args & body)
            quote-replace
              defn ~f-name ~args
                &let
                  ~f-name $ defn ~f-name ~args ~@body
                  call-with-log ~f-name ~@args

        |let{} $ quote
          defmacro let{} (binding & body)
            assert "|expects 2 items in list of binding"
              &and (list? binding) (&= 2 (count binding))
            let
                items $ first binding
                base $ last binding
                var-result $ gensym |result
              assert (str "|expects symbol names in binding names: " items)
                every? symbol? items
              quote-replace
                &let
                  ~var-result ~base
                  let
                    ~ $ map
                      defn gen-items% (x)
                        [] x ([] (turn-keyword x) var-result)
                      , items
                    ~@ body

        |conf $ quote
          def conf append

        |turn-str $ quote
          def turn-str turn-string

        |reduce $ quote
          def reduce foldl

        |dbt $ quote
          def dbt dual-balanced-ternary
