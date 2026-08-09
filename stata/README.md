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
