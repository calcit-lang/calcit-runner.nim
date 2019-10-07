
println
  {}


println
  {}
    1 "|one"
    2 "|two"

println
  {}
    |demo |a
    |quote |b
    2 |two

println
  ({} (|two 22) (|three 33)) get |two

println
  (({} (|two 22) (|three 33)) add |four 44) get |four
