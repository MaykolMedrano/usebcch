<div align="center">

# usebcch

**Acceso reproducible a las series estadísticas del Banco Central de Chile desde Stata.**

[![Checks](https://img.shields.io/github/actions/workflow/status/MaykolMedrano/usebcch/ci.yml?branch=main&style=flat-square&label=checks)](https://github.com/MaykolMedrano/usebcch/actions)
[![Stata](https://img.shields.io/badge/Stata-16%2B-2e7d32?style=flat-square)](https://www.stata.com/)
[![bcchapi](https://img.shields.io/pypi/v/bcchapi?style=flat-square&label=bcchapi)](https://pypi.org/project/bcchapi/)
[![BDE API](https://img.shields.io/badge/API-BCCh%20BDE-005baa?style=flat-square)](https://si3.bcentral.cl/estadisticas/Principal1/Web_Services/index.htm)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)

</div>

## Descripción

Este repositorio contiene la implementación nativa para Stata del acceso a la
Base de Datos Estadísticos (BDE) del Banco Central de Chile (BCCh). `usebcch`
descarga una o varias series, busca códigos en el catálogo y ofrece
transformaciones, caché y metadatos sin depender de la integración de Python.

La implementación Stata es independiente y no constituye un producto oficial
del Banco Central de Chile.

## Implementación en Python

El Banco Central de Chile también publica el comando Python **`bcchapi`** para
utilizar su API BDE. Este repositorio no duplica ese código: `usebcch` es la
implementación nativa equivalente para usuarios de Stata.

Para instalar la implementación Python:

```bash
pip install bcchapi
```

Ayuda: [bcchapi en PyPI](https://pypi.org/project/bcchapi/) · [ejemplos
oficiales de la API BDE](https://si3.bcentral.cl/estadisticas/Principal1/Web_Services/ejemplos.htm)

La API Python y `usebcch` requieren una cuenta propia del portal BDE/SI3.

## Implementación en Stata

Requiere Stata 16 o superior y acceso HTTPS.

Para una copia local del repositorio:

```stata
net install usebcch, from("C:/ruta/usebcch/stata") replace
```

Cuando el repositorio se publique, `from()` debe apuntar al directorio raw
`stata/` que contenga `stata.toc` y `usebcch.pkg`, no a una página HTML ni a un
archivo ZIP.

Ayuda: [guía de usuario](stata/docs/GUIA_USUARIO.md) · [ayuda de
Stata](stata/usebcch.sthlp) · [especificación técnica](stata/docs/SPEC.md) ·
[guía de distribución](stata/docs/DISTRIBUTION.md)

Replicación: [suite de pruebas Stata](stata/tests/)

## Credenciales BDE/SI3

Cada usuario debe crear o activar sus propias credenciales en el [portal
BDE/SI3](https://si3.bcentral.cl/siete). `usebcch` no crea cuentas, no entrega
usuarios ni contraseñas y nunca distribuye credenciales.

La opción recomendada es registrar una vez un archivo `.env` privado:

```stata
usebcch auth set, envfile("C:/private/bcch.env")
usebcch auth status
```

El archivo `.env` es personal y nunca debe incluirse en el repositorio. También
pueden utilizarse `BCCH_USER` y `BCCH_PASSWORD` como variables de entorno o la
opción `credentials()` para archivos de dos líneas.

## Ejemplos

```stata
* Una serie diaria
usebcch get F073.TCO.PRE.Z.D, from(2024-01-01) to(2024-12-31) clear

* Varias series con nombres legibles
usebcch get F073.TCO.PRE.Z.D F022.TPM.TIN.D001.NO.Z.D, ///
    names(dolar tpm) from(2024-01-01) clear

* Conversión mensual y variación interanual
usebcch get F073.TCO.PRE.Z.D, names(dolar) from(2020-01-01) ///
    frequency(monthly) aggregate(mean) variation(12) clear

* Búsqueda del catálogo
usebcch search "IPC", frequency(monthly) language(es) clear
```

## Pruebas y distribución

Desde la raíz del repositorio, con StataNow 19 configurado en
`C:\Program Files\StataNow19\StataSE-64.exe`:

```powershell
powershell -ExecutionPolicy Bypass -File stata/scripts/run-tests.ps1
```

Para preparar una distribución Stata:

```powershell
powershell -ExecutionPolicy Bypass -File stata/scripts/build-release.ps1
```

## Estructura del repositorio

```text
usebcch/
├── stata/
│   ├── README.md                   guía del runtime Stata
│   ├── *.ado, *.mata, *.sthlp      runtime nativo instalable
│   ├── stata.toc, usebcch.pkg  sitio net install
│   ├── tests/                   pruebas y fixtures
│   ├── docs/                    documentación Stata
│   └── scripts/                 pruebas y distribución
├── CHANGELOG.md
├── LICENSE
└── README.md
```

La fuente y el comportamiento de referencia se basan en el código público MIT
de [`bcchapi`](https://pypi.org/project/bcchapi/), mientras que el transporte
HTTP, el parser JSON y la materialización de datasets son nativos de Stata/Mata.

## Fuente oficial

- [Banco Central de Chile](https://www.bcentral.cl/)
- [API BDE y condiciones de uso](https://si3.bcentral.cl/estadisticas/Principal1/Web_Services/index.htm)
- [Portal BDE/SI3](https://si3.bcentral.cl/siete)

## Autor

**Maykol Medrano**<br>
Pontificia Universidad Católica de Chile<br>
Email: [mmedrano2@uc.cl](mailto:mmedrano2@uc.cl)<br>
GitHub: [MaykolMedrano](https://github.com/MaykolMedrano)

## Licencia

MIT. Consulte [LICENSE](LICENSE).
