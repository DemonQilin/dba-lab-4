# Entorno Oracle Database — Administración de Base de Datos

Entorno reproducible con **Oracle Database** corriendo en Docker, listo para usar desde VS Code mediante **Dev Containers**. Incluye:

- **SQL*Plus** (Oracle Instant Client) en el contenedor de desarrollo: el mismo cliente con el que se revisa el script.
- La extensión **SQL Developer Extension for VS Code** (`oracle.sql-developer`) preinstalada, para ejecutar fragmentos durante la exposición.
- Oracle **23ai** por defecto, con opción de cambiar a **21c XE** o **18c XE** (proxy de 19c) para probar la compatibilidad del script.

## Requisitos previos

Antes de abrir este proyecto, instala en tu máquina:

1. **[Docker Desktop](https://www.docker.com/products/docker-desktop/)** (Windows/Mac) o Docker Engine (Linux)
2. **[Visual Studio Code](https://code.visualstudio.com/)**
3. La extensión de VS Code **[Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)** (`ms-vscode-remote.remote-containers`)

## Estructura del proyecto

```
.
├── .devcontainer/
│   ├── devcontainer.json     # Configuración de VS Code para el Dev Container
│   ├── Dockerfile            # Contenedor de desarrollo con SQL*Plus
│   ├── docker-compose.yml    # Definición de los contenedores (app + oracle)
│   ├── .env.example           # Plantilla de variables de entorno (sí se sube a Git)
│   └── .env                    # Tus contraseñas reales (NO se sube a Git)
└── .gitignore
```

## Puesta en marcha (primera vez)

### 1. Clonar el repositorio

```bash
git clone <url-del-repositorio>
cd <carpeta-del-proyecto>
```

### 2. Crear tu archivo de variables de entorno

```bash
cp .devcontainer/.env.example .devcontainer/.env
```

Abre `.devcontainer/.env` y define la contraseña de `SYS` y `SYSTEM`:

```
ORACLE_PASSWORD=TuPasswordSegura123
```

El resto del archivo selecciona la versión de Oracle (ver [Cambiar de versión de Oracle](#cambiar-de-versión-de-oracle)). Si no lo tocas, se usa 23ai.

> Este archivo es local a tu máquina y está en `.gitignore` — nunca se comparte ni se sube al repositorio.
>
> **Importante:** el `.env` debe estar dentro de `.devcontainer/`, junto al `docker-compose.yml`. Docker Compose busca el archivo `.env` en el mismo directorio que el `docker-compose.yml` que está usando; si lo pones en la raíz del proyecto, las variables quedan vacías y el contenedor de Oracle falla al arrancar.

### 3. Abrir el proyecto en VS Code

```bash
code .
```

### 4. Reabrir en el Dev Container

VS Code mostrará una notificación abajo a la derecha: **"Reopen in Container"**. Haz clic ahí.

(Si no aparece la notificación: `Ctrl+Shift+P` → busca **"Dev Containers: Reopen in Container"**)

### 5. Esperar la inicialización

La primera vez, Docker debe descargar las imágenes y Oracle debe inicializar la base de datos — puede tardar varios minutos. Puedes seguir el progreso en la pestaña **"Dev Containers"** del panel de salida (Output) de VS Code.

Cuando termine, ya tienes:

- Oracle Database corriendo en `localhost:1521`
- SQL*Plus disponible en la terminal del contenedor
- La extensión de Oracle instalada y lista dentro del contenedor

## Datos de conexión

Usa estos datos en la extensión de Oracle, DBeaver, SQL Developer, etc. Funcionan igual desde tu máquina y desde dentro del contenedor (el contenedor `app` comparte la red de `oracle`, así que `localhost:1521` es la base de datos en ambos lados):

| Campo             | Valor                                                           |
| ----------------- | --------------------------------------------------------------- |
| Host              | `localhost`                                                     |
| Puerto            | `1521`                                                          |
| Service name      | `FREEPDB1` (23ai) o `XEPDB1` (21c / 18c)                        |
| Usuario           | `system` (los usuarios del taller los crea el script)           |
| Contraseña        | La que definiste en tu `.devcontainer/.env`                     |
| Role / Connect as | `Default` (deja `SYSDBA` únicamente para conectarte como `sys`) |

## SQL*Plus

Desde una terminal del Dev Container, la variable `ORACLE_CONN` ya contiene la cadena de conexión de la versión activa:

```bash
sqlplus system@$ORACLE_CONN          # pide la contraseña
SQL> @/workspace/<script>.sql        # ejecutar un script
```

En la terminal interactiva `sqlplus` tiene historial con las flechas (via `rlwrap`).

## Cambiar de versión de Oracle

En `.devcontainer/.env` deja descomentado **un solo bloque** (las tres variables van juntas):

| Versión | `ORACLE_IMAGE`                               | `ORACLE_SERVICE` | `ORACLE_VOLUME` |
| ------- | -------------------------------------------- | ---------------- | --------------- |
| 23ai    | `gvenzl/oracle-free:23.26.4-slim-faststart`  | `FREEPDB1`       | `23`            |
| 21c XE  | `gvenzl/oracle-xe:21.3.0-slim-faststart`     | `XEPDB1`         | `21`            |
| 18c XE  | `gvenzl/oracle-xe:18.4.0-slim-faststart`     | `XEPDB1`         | `18`            |

Luego `Ctrl+Shift+P` → **Dev Containers: Rebuild Container**. Cada versión guarda sus datos en su propio volumen (`lab4-oracle-23`, `lab4-oracle-21`, `lab4-oracle-18`).

- Las imágenes 21c y 18c solo existen para `amd64` (no corren nativamente en Mac con Apple Silicon).
- 19c no tiene imagen gratuita liviana; 18c y 19c son la misma familia (12.2), por eso 18c sirve como prueba de compatibilidad.

## Exposición con la extensión: ojo con las sesiones abiertas

Cada conexión de la extensión es una sesión persistente:

- Revocar un **privilegio de un rol** tiene efecto inmediato, incluso en sesiones abiertas.
- Revocar un **rol a un usuario** solo se aplica en una **sesión nueva**.

Después de revocar un rol, **desconecta y vuelve a conectar** la conexión de ese usuario antes de verificar. En SQL*Plus no pasa, porque cada `CONNECT` abre una sesión nueva.

## Comandos útiles

Desde una terminal en la raíz del proyecto (fuera o dentro del Dev Container):

```bash
# Detener los contenedores sin perder datos
docker compose -f .devcontainer/docker-compose.yml stop

# Volver a levantarlos
docker compose -f .devcontainer/docker-compose.yml start

# Ver logs de Oracle (útil si algo no arranca)
docker compose -f .devcontainer/docker-compose.yml logs -f oracle

# Ver el estado de los contenedores
docker compose -f .devcontainer/docker-compose.yml ps
```

## Persistencia de datos

- Tus datos (tablas, usuarios, cambios) se guardan en un volumen de Docker y **sobreviven** cada vez que cierras y vuelves a abrir el Dev Container en tu máquina.
- Los datos **no se comparten entre compañeros** — cada quien tiene su propia copia local, aislada. Lo único que se comparte vía Git es la configuración (este README, el `docker-compose.yml`, el `devcontainer.json`).

## Empezar de cero (borrar todo y reiniciar)

Si necesitas resetear completamente tu base de datos local:

```bash
docker compose -f .devcontainer/docker-compose.yml down -v
```

El flag `-v` elimina también el volumen de datos. La próxima vez que reabras el Dev Container, Oracle se inicializará desde cero.

## Solución de problemas

**"Credenciales inválidas" en la extensión de VS Code:**
Verifica que el campo _Role_ esté en `Default` y no en `SYSDBA` (ese modo es solo para conectarte como `sys`).

**El contenedor tarda mucho en arrancar la primera vez:**
Es normal — Oracle inicializa la base de datos completa en el primer arranque (varios minutos). Los arranques siguientes son mucho más rápidos.

**El contenedor `oracle` sale con "Error" apenas arranca / el log dice "Oracle Database SYS and SYSTEM passwords have to be specified":**
El archivo `.env` no está en `.devcontainer/.env` (revisa el paso 2), o el contenedor ya se había creado antes con las variables vacías y no se recreó. Corrígelo así:

```bash
docker compose -f .devcontainer/docker-compose.yml down -v
```

y vuelve a reabrir el Dev Container para que se cree desde cero con las variables correctas.

## Limpieza total (desinstalar todo)

Al terminar el curso, para no dejar ningún rastro en tu máquina:

```bash
docker compose -f .devcontainer/docker-compose.yml down -v --rmi all
```

Esto elimina los contenedores, el volumen de datos y las imágenes descargadas.
