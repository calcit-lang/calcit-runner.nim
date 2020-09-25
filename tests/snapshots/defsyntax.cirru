
{} (:package |app)
  :configs $ {} (:init-fn |app.main/main!) (:reload-fn |app.main/reload!)
  :files $ {}
    |app.main $ {}
      :ns $ quote
        ns app.main $ :require
      :defs $ {}
        |syntax-add $ quote
          defsyntax syntax-add (a b c)
            + (eval a) (eval b) (eval c)
        |main! $ quote
          defn main! () (syntax-add 1 2 3)

      :proc $ quote ()
      :configs $ {} (:extension nil)
