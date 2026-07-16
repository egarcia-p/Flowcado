# Flowcado

App para entrar en estado de enfoque usando la técnica Pomodoro.

---

## Desarrollo local

```bash
# Instalar dependencias del cliente
cd src/client && npm install

# Instalar dependencias del servidor
cd src/server && npm install

# Arrancar el servidor (desde src/server/)
node server.js
```

El servidor queda disponible en `http://localhost:3001`.

---

## Despliegue en Raspberry Pi

El script `deploy-to-pi.sh` construye la imagen Docker para ARM64 en tu Mac,
la transfiere a la Pi por SSH y reinicia el stack de forma automática.

### Prerrequisitos

| Requisito | Detalle |
|-----------|---------|
| Docker Desktop (Mac) | Debe estar **arrancado** con Buildx habilitado |
| SSH a la Pi | `user@host.local` — autenticación por contraseña o clave |
| Docker + Compose en la Pi | Ya instalados en `~/Flowcado/` |

> **Primera vez:** asegúrate de que existe el directorio de datos en la Pi:
> ```bash
> ssh user@host.local "mkdir -p ~/Flowcado/data"
> ```

### Desplegar una nueva versión

Desde la raíz del proyecto en tu Mac:

```bash
chmod +x deploy-to-pi.sh   # solo la primera vez
./deploy-to-pi.sh
```

El script realiza estos pasos automáticamente:

1. **Buildx** — crea un builder `linux/arm64` si no existe
2. **Build** — compila la imagen `flowcado:latest` para ARM64 (puede tardar varios minutos la primera vez por la compilación nativa de SQLite)
3. **Export** — guarda la imagen como `flowcado-arm64.tar`
4. **Transfer** — copia el tar y el `docker-compose.yml` a `user@host.local:~/Flowcado/` via `scp`
5. **Load & restart** — carga la imagen en la Pi y reinicia el stack con `docker compose`
6. **Cleanup** — te pregunta si borrar el tar local

### Opciones avanzadas

Puedes sobreescribir los valores por defecto con variables de entorno:

```bash
PI_HOST=host.local PI_USER=user PI_PATH=~/Flowcado ./deploy-to-pi.sh
```

O pasando argumentos posicionales:

```bash
./deploy-to-pi.sh host.local user ~/Flowcado
```

### Verificar que la app está corriendo

```bash
# Ver estado del stack
ssh user@host.local "docker compose -f ~/Flowcado/docker-compose.yml ps"

# Ver logs en tiempo real
ssh user@host.local "docker compose -f ~/Flowcado/docker-compose.yml logs -f flowcado"
```

La app queda accesible en:

- **Directo:** `http://host.local:3001`
- **Via Caddy:** `http://host.local`

### Estructura de datos persistentes

La base de datos SQLite se guarda en la Pi en `~/Flowcado/data/flowcado.db`.
Al estar montada como bind mount, puedes hacer backup fácilmente:

```bash
scp user@host.local:~/Flowcado/data/flowcado.db ./backup-$(date +%F).db
```

### Solución de problemas

| Síntoma | Causa probable | Solución |
|---------|---------------|----------|
| `SQLITE_CANTOPEN` | Contenedor apuntando a directorio incorrecto | `docker stop flowcado && docker rm flowcado` y volver a lanzar desde `~/Flowcado/` |
| `permission denied` al hacer SSH | Clave SSH no configurada | `ssh-copy-id user@host.local` |
| Build muy lento | Primera compilación nativa de SQLite para ARM64 | Esperar; las siguientes builds usan caché de capas |
| Puerto 3001 ocupado | Otro proceso o contenedor usando el puerto | `ssh user@host.local "docker ps"` para identificarlo |
