
{} (:package |app)
  :files $ {}
    |app.main $ {} (:ns $ [] |ns |app.main)
      :defs $ {}
        |main! $ [] |defn |main! ([]) ([] |println "|\"main loaded.")
        |echo $ [] |defn |echo ([]) ([] |println |2)
      :proc $ []
      :configs $ {}
    |app.lib $ {} (:ns $ [] |ns |app.lib)
      :defs $ {}
        |handle $ [] |defn |handle ([]) ([] |echo "|\"2")
        |emit $ [] |defn |emit ([])
      :proc $ []
      :configs $ {}
    |app.core $ {} (:ns $ [] |ns |app.core)
      :defs $ {}
        |cute $ [] |defn |cute ([])
      :proc $ [] ([] |echo |1)
      :configs $ {}
