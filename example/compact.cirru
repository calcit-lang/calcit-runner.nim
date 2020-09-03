
{} (:package |app)
  :files $ {}
    |app.main $ {}
      :ns $ quote (ns app.main)
      :defs $ {}
        |main! $ quote
          defn main! () (println "\"main loaded!")
        |echo $ quote
          defn echo () (println 2)
      :proc $ quote ()
      :configs $ {}
    |app.lib $ {}
      :ns $ quote (ns app.lib)
      :defs $ {}
        |handle $ quote
          defn handle () (echo "\"2")
        |emit $ quote (defn emit $)
      :proc $ quote ()
      :configs $ {}
    |app.core $ {}
      :ns $ quote (ns app.core)
      :defs $ {}
        |cute $ quote (defn cute $)
      :proc $ quote
          echo 1
      :configs $ {}
