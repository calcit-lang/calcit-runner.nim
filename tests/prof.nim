
import nimprof
import times
import calcit_runner

let t1 = now()

main()

let t2 = now()

echo "Cost: ", t2 - t1
