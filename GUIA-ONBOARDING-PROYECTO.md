# Guía: Conectar un proyecto existente al servidor GitLab local

Esta guía describe cómo subir un repositorio existente al servidor GitLab local, registrar un runner y ejecutar un primer pipeline de prueba de forma aislada, sin afectar el repositorio de origen.

## Prerrequisitos

- Servidor GitLab local corriendo (`make up` en este directorio)
- Acceso a la UI en la URL configurada en `.env` (por defecto `http://localhost:8929`)
- Credenciales de `root` obtenidas con `make password`
- Proyecto Git existente en el equipo local

---

## 1. Crear un repositorio en GitLab local

1. Ingresar a `http://localhost:8929` con el usuario `root`.
2. En la barra superior, hacer clic en **"+"** > **New project**.
3. Seleccionar **Create blank project**.
4. Completar:
   - **Project name:** nombre del proyecto
   - **Visibility Level:** Private (recomendado para pruebas)
   - Desmarcar *Initialize repository with a README* si el proyecto ya tiene historial
5. Hacer clic en **Create project**.

GitLab mostrará la URL del repositorio recién creado:
```
http://localhost:8929/<usuario>/<nombre-proyecto>.git
```

---

## 2. Conectar el proyecto existente

Desde el directorio del proyecto local, agregar el servidor GitLab local como un remote adicional. **No es necesario eliminar ni modificar el remote de origen** (`origin`).

```bash
# Agregar el servidor local como remote "local"
git remote add local http://localhost:8929/root/<nombre-proyecto>.git

# Verificar que ambos remotes coexisten
git remote -v

# Subir la rama de trabajo al servidor local
git push local <rama-actual>

# Para subir todas las ramas de una vez
git push local --all
```

> Si el proyecto aún no tiene remote, usar `local` como nombre o `origin` directamente — es indistinto.

**Problema frecuente: `shallow update not allowed`**

Si el repositorio fue clonado con `--depth` (shallow clone), GitLab rechazará el push porque no puede construir el historial completo. Solución: completar el historial antes de hacer el push.

```bash
# Completar el historial desde el remote de origen
git fetch --unshallow origin

# Reintentar el push
git push local --all
```

---

## 3. Registrar un GitLab Runner

El runner ejecuta los jobs del pipeline. Se levanta como un contenedor Docker separado del servidor GitLab.

### 3.1 Crear el runner en la UI

1. Ir al proyecto en GitLab > **Settings** > **CI/CD** > sección **Runners**.
2. Hacer clic en **New project runner**.
3. Configurar:
   - **Operating System:** Linux
   - **Tags:** agregar una etiqueta, por ejemplo `docker` (se usará en el `.gitlab-ci.yml`)
   - Marcar **Run untagged jobs** si se quiere que el runner levante cualquier job sin tags
4. Hacer clic en **Create runner**.
5. GitLab mostrará un token de autenticación con el prefijo `glrt-`. **Copiarlo ahora** — solo se muestra una vez.

### 3.2 Registrar el runner

Ejecutar el siguiente comando reemplazando `<TOKEN>` con el valor obtenido en el paso anterior.

> **En macOS**, el runner corre en un contenedor y debe usar `host.docker.internal` para alcanzar el servidor GitLab (que corre en el host). Reemplazar `localhost` por esa dirección solo en este paso.

```bash
docker run --rm \
  -v ~/.gitlab-runner:/etc/gitlab-runner \
  gitlab/gitlab-runner register \
  --non-interactive \
  --url "http://host.docker.internal:8929" \
  --token "<TOKEN>" \
  --executor "docker" \
  --docker-image "alpine:latest" \
  --docker-network-mode "host" \
  --description "Local Docker Runner"
```

Esto genera el archivo de configuración en `~/.gitlab-runner/config.toml`.

> **En macOS**, Docker Desktop solo permite montar rutas bajo `/Users`, `/tmp` y similares. Rutas como `/srv` requieren habilitarse manualmente en **Docker Desktop → Settings → Resources → File Sharing**. Usar `~/.gitlab-runner` evita esa fricción.

### 3.3 Levantar el runner

```bash
docker run -d \
  --name gitlab-runner \
  --restart always \
  -v ~/.gitlab-runner:/etc/gitlab-runner \
  -v /var/run/docker.sock:/var/run/docker.sock \
  gitlab/gitlab-runner:latest
```

### 3.4 Verificar que el runner está activo

En GitLab: **Settings** > **CI/CD** > **Runners**. El runner recién registrado debe aparecer con un círculo verde.

---

## 4. Primer pipeline de prueba

Crear un archivo `.gitlab-ci.yml` en la raíz del proyecto con un pipeline mínimo. Este ejemplo valida que el runner funciona sin ejecutar nada que afecte el entorno real.

```yaml
stages:
  - validate

lint:
  stage: validate
  image: alpine:latest
  tags:
    - docker
  script:
    - echo "Pipeline funcionando correctamente"
    - echo "Rama: $CI_COMMIT_BRANCH"
    - echo "Commit: $CI_COMMIT_SHORT_SHA"
```

Subir el archivo al servidor local y observar el resultado:

```bash
git add .gitlab-ci.yml
git commit -m "chore: pipeline de prueba local"
git push local <rama-actual>
```

En GitLab ir a **CI/CD** > **Pipelines** para ver el pipeline ejecutándose.

---

## 5. Evolucionar el pipeline con seguridad

Una vez verificado el runner, agregar stages reales de forma incremental. Orden recomendado:

1. **Validación** — detección de secretos (`gitleaks`, `trufflehog`), linters
2. **Build** — compilar el artefacto
3. **Test** — unitarios + cobertura
4. **Análisis** — SAST (`semgrep`), dependencias vulnerables (`trivy`)

Ejemplo de stage de detección de secretos (seguro para ejecutar localmente):

```yaml
stages:
  - validate

detect-secrets:
  stage: validate
  image: zricethezav/gitleaks:latest
  tags:
    - docker
  script:
    - gitleaks detect --source . --verbose
  allow_failure: false
```

> Ejecutar primero en una rama separada (`test/pipeline-local`) para no mezclar experimentos con el historial del proyecto.

---

## Notas

- El remote `local` y el remote `origin` son independientes. Hacer `git push local` no afecta el repositorio de origen.
- El runner registrado es de alcance de proyecto (solo ejecuta jobs de ese proyecto). Para reutilizarlo en otros proyectos, registrarlo a nivel de grupo o instancia desde **Admin Area** > **CI/CD** > **Runners**.
- Para detener el runner: `docker stop gitlab-runner && docker rm gitlab-runner`.
- Para limpiar la configuración del runner: eliminar o limpiar `/srv/gitlab-runner/config/config.toml` y repetir el registro.
