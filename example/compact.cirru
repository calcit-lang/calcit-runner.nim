
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
        |handle $ [] |defn |handle ([]) ([] |echo "|\"1")
      :proc $ []
      :configs $ {}
