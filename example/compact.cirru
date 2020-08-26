
{} (:package |app)
  :files $ {}
    |app.main $ {} (:ns $ [] |ns |app.main)
      :defs $ {}
        |main! $ [] |defn |main! ([]) ([] |println "|\"main loaded.")
        |echo $ [] |defn |echo ([]) ([] |println "|\"this is just echo2")

      :configs $ {}
