# Implementación nativa Stata (`usebcch`)

Esta carpeta contiene el runtime completo de `usebcch` y es el sitio exacto
para `net install`. `stata.toc` y `usebcch.pkg` deben permanecer directamente
en esta carpeta.

## Instalación

```stata
net install usebcch, ///
    from("https://raw.githubusercontent.com/MaykolMedrano/usebcch/main/stata") replace
```

Para desarrollo local, sustituya la URL por la ruta de su carpeta `stata/`.

El paquete requiere Stata 16 o superior, HTTPS y credenciales propias del
portal BDE/SI3 del Banco Central de Chile.

## Credenciales

La documentación pública del BCCh indica crear una cuenta BDE y activar las
credenciales de la API. Use el usuario y contraseña que entregue el portal; si
su cuenta muestra **Mi Cuenta > Apikey Token**, también puede usar BCCH_TOKEN.

Guárdelo en un archivo privado:

```text
BCCH_TOKEN=mi_api_key_token
```

Después registre la ruta:

```stata
usebcch auth set, envfile("C:/private/bcch.env")
usebcch auth status
```

También se admite `BCCH_TOKEN`, `token()` o un archivo de una sola línea en
`credentials()`. `BCCH_USER` y `BCCH_PASSWORD` quedan disponibles como
compatibilidad heredada. El límite publicado es de cinco series por segundo por
cuenta.
## Desarrollo

Desde la raíz del repositorio:

```powershell
powershell -ExecutionPolicy Bypass -File stata/scripts/run-tests.ps1
```

- [Guía de usuario](docs/GUIA_USUARIO.md)
- [Especificación técnica](docs/SPEC.md)
- [Distribución](docs/DISTRIBUTION.md)
- [Pruebas y fixtures](tests/)
- [Catálogo Python de referencia](https://pypi.org/project/bcchapi/)
