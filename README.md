# gitlab-server

Servidor GitLab CE local levantado con Docker Compose. Pensado para desarrollo y pruebas internas — no para producción.

## Prerrequisitos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) instalado y corriendo
- `make` disponible en el sistema (incluido por defecto en macOS y Linux)

## Inicialización

```bash
# 1. Clonar o posicionarse en el directorio
cd gitlab-server

# 2. Crear el archivo de configuración local
make install

# 3. (Opcional) Ajustar puertos u otras variables en .env antes de continuar

# 4. Levantar el servidor
make up
```

GitLab tarda ~2–3 minutos en inicializar todos sus servicios internos. Si el navegador muestra un error 502, esperar y recargar.

## Primer acceso

```bash
# Obtener la contraseña inicial del usuario root
make password

# Abrir GitLab en el navegador
make open
```

Ingresar con usuario `root` y la contraseña obtenida en el paso anterior.
> La contraseña inicial es válida solo **24 horas** desde el primer arranque. Cambiarla inmediatamente tras el primer login en **User Settings → Password**.

## Comandos disponibles

| Comando | Descripción |
|---|---|
| `make install` | Crea `.env` desde `.env.example` si no existe |
| `make up` | Levanta GitLab en segundo plano |
| `make down` | Detiene y elimina los contenedores (los datos persisten) |
| `make logs` | Muestra los logs en tiempo real |
| `make password` | Muestra la contraseña inicial de `root` |
| `make open` | Abre GitLab en el navegador |

## Configuración

Todas las variables se definen en `.env` (generado por `make install` a partir de `.env.example`):

| Variable | Default | Descripción |
|---|---|---|
| `GITLAB_HOME` | `./gitlab-data` | Directorio local donde se persisten datos, logs y configuración |
| `GITLAB_VERSION` | `latest` | Versión de la imagen `gitlab/gitlab-ce` |
| `GITLAB_EXTERNAL_URL` | `http://localhost:8929` | URL de acceso desde el navegador y base para los links internos de GitLab |
| `GITLAB_HTTP_PORT` | `8929` | Puerto HTTP expuesto en el host |
| `GITLAB_HTTPS_PORT` | `8930` | Puerto HTTPS expuesto en el host |
| `GITLAB_SSH_PORT` | `2222` | Puerto SSH expuesto en el host (para `git clone` vía SSH) |

> `GITLAB_EXTERNAL_URL` y `GITLAB_HTTP_PORT` deben coincidir. Si se cambia el puerto, actualizar ambas variables.

## Conectar un proyecto existente

Ver [`GUIA-ONBOARDING-PROYECTO.md`](./GUIA-ONBOARDING-PROYECTO.md) para instrucciones paso a paso sobre cómo subir un repositorio existente, registrar un runner y ejecutar un primer pipeline de prueba.

---

## Datos persistentes

Los volúmenes se almacenan en el directorio definido por `GITLAB_HOME`:

```
gitlab-data/
├── config/   # gitlab.rb y certificados
├── logs/     # logs de todos los servicios internos
└── data/     # repositorios, base de datos y artefactos
```

`make down` detiene los contenedores pero **no borra los datos**. Para un reset completo eliminar el directorio `GITLAB_HOME` manualmente.
