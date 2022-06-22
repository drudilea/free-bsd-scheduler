1. Posicionarse dentro de la carpeta del proyecto
2. Revisar si el repositorio de `freebsd-src` se encuentra dentro de los remotos de git con el siguiente comando

   ```bash
    git remote -v
   ```

   1. Si está dentro de los remotos, entonces tendremos una respuesta similar a la siguiente

      ```bash
      origin	git@github.com:drudilea/freebsd-src.git (fetch)
      origin	git@github.com:drudilea/freebsd-src.git (push)
      upstream	git@github.com:freebsd/freebsd-src.git (fetch)
      upstream	git@github.com:freebsd/freebsd-src.git (push)
      ```

   2. Si no está dentro de los remotos, entonces tendremos una respuesta similar a la siguiente

      ```bash
      origin	git@github.com:drudilea/freebsd-src.git (fetch)
      origin	git@github.com:drudilea/freebsd-src.git (push)
      ```

      Y deberíamos agregar el repositorio de `freebsd-src` a los remotos con el siguiente comando (elegir SSH o HTTPS según corresponda)

      ```bash
      # SSH
      git remote add upstream git@github.com:drudilea/freebsd-src.git

      # HTTPS
      git remote add upstream https://github.com/freebsd/freebsd-src.git
      ```

      Revisar que el repositorio de `freebsd-src` se encuentra dentro de los remotos de git

3. Obtener los últimos commits del nuevo remoto `upstream`
   ```bash
    git fetch upstream
   ```
4. Cambiar a la rama que no se encontraba en el remoto previo, pero que ahora si se encuentra en el recientemente agregado, por ejemplo en este caso la rama `release/13.1.0`
   ```bash
   # git checkout <branchName>
   git checkout release/13.1.0
   ```
5. Subir esta rama al remoto `origin`

   ```bash
    # git push origin <branchName>
    git push origin release/13.1.0
   ```

---

## Bibliografía

- [Configuring a remote for a fork](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/configuring-a-remote-for-a-fork)
- [Syncing a fork](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/syncing-a-fork)
- [Sync new branch in my fork from the original repository](https://stackoverflow.com/a/33488139)
