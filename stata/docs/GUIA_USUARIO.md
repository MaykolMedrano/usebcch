# Guía de usuario de `usebcch`

`usebcch` descarga y busca series de la Base de Datos Estadísticos (BDE) del
Banco Central de Chile directamente desde Stata 16 o superior. No requiere
Python, pero la API del BCCh sí exige usuario y contraseña.

## 1. Instalación local

Mientras el proyecto no esté publicado en una dirección web, instálelo desde
la subcarpeta `stata/`, que contiene `stata.toc` y `usebcch.pkg`:

```stata
net install usebcch, ///
    from("C:/Users/horio/OneDrive - Universidad Católica de Chile/Proyectos_GitHub/usebcch/stata") ///
    replace
help usebcch
```

`net install` acepta una ruta local en `from()`. No anteponga `file://` y use
barras `/` para evitar problemas con espacios y barras invertidas.

## 2. Crear la cuenta BDE/SI3 y registrar las credenciales

Antes del primer llamado, cada usuario debe crear o activar su propia cuenta
en el [portal BDE/SI3](https://si3.bcentral.cl/siete). Seleccione
**Registrarse** y siga las instrucciones del Banco Central de Chile. Si ya
tiene una cuenta, use **Usuario Registrado**; para recuperar el acceso,
seleccione **Recuperar Contraseña**.

`usebcch` no crea cuentas, no entrega usuarios ni contraseñas y no permite
compartir las credenciales de otra persona. Después de obtener su usuario y
contraseña, guárdelos en un archivo privado:

Cree un archivo privado, por ejemplo `C:/credenciales/bcch.env`, con estas dos
líneas:

```text
BCCH_USER=mi_usuario
BCCH_PASSWORD=mi_contraseña
```

Registre su ubicación en Stata:

```stata
usebcch auth set, envfile("C:/credenciales/bcch.env")
usebcch auth status
```

Desde ese momento no necesita repetir `envfile()` en cada llamada. `usebcch`
guarda únicamente la ruta del archivo bajo el directorio `PERSONAL` de Stata;
no copia las credenciales. Para olvidar la ruta registrada:

```stata
usebcch auth clear
```

El archivo `.env` nunca debe incorporarse al repositorio ni a un paquete de
distribución. También se admiten las variables de entorno `BCCH_USER` y
`BCCH_PASSWORD`, un `.env` en el directorio de trabajo o las opciones explícitas
`envfile()` y `credentials()`; consulte `help usebcch` para la precedencia.

## 3. Encontrar el código de una serie

No es necesario conocer el código de antemano. Busque primero por texto:

```stata
usebcch search "tipo de cambio", frequency(daily) clear
usebcch search "IPC", frequency(monthly) language(es) clear
usebcch search "^ipc.*subyacente", frequency(monthly) regex cache clear
```

La consulta que contiene espacios o acentos debe ir entre comillas rectas
(`"..."`). `cache` conserva localmente el catálogo; `refresh` fuerza su
actualización. La columna `series_id` contiene el código que luego se usa en
`get`.

## 4. Descargar series

Una serie:

```stata
usebcch get F073.TCO.PRE.Z.D, ///
    from(2024-01-01) to(2024-12-31) clear
```

Varias series con nombres amigables:

```stata
usebcch get F073.TCO.PRE.Z.D F022.TPM.TIN.D001.NO.Z.D, ///
    names(dolar tpm) from(2024-01-01) clear
```

El resultado predeterminado es ancho: `time` más una variable numérica por
serie. `long` entrega una fila por fecha y serie, además de códigos de estado y
títulos:

```stata
usebcch get F073.TCO.PRE.Z.D F022.TPM.TIN.D001.NO.Z.D, long clear
```

`clear` autoriza reemplazar los datos que estén en memoria. Sin esa opción,
Stata protege el dataset abierto.

## 5. Fechas, frecuencias y variaciones

`from()` y `to()` usan fechas ISO `YYYY-MM-DD`. La variable temporal siempre se
llama `time` y queda en la escala nativa de Stata correspondiente al resultado:

| Frecuencia final | Formato de `time` |
|---|---|
| diaria | `%td` |
| mensual | `%tm` |
| trimestral | `%tq` |
| anual | `%ty` |

Por eso se puede ejecutar directamente:

```stata
tsset time
```

Para reducir la frecuencia se debe indicar cómo agregar cada serie:

```stata
usebcch get F073.TCO.PRE.Z.D F022.TPM.TIN.D001.NO.Z.D, ///
    names(dolar tpm) from(2020-01-01) to(2024-12-31) ///
    frequency(monthly) aggregate(mean last) clear
```

`variation(12)` calcula `valor_actual/valor_12_periodos_atrás - 1` después de la
agregación:

```stata
usebcch get F073.TCO.PRE.Z.D, names(dolar) from(2020-01-01) ///
    frequency(monthly) aggregate(mean) variation(12) clear
```

Las primeras 12 observaciones quedan faltantes por definición: todavía no
existe una observación comparable 12 meses atrás. Los huecos del calendario no
se saltan. El resultado es una fracción (`0.05` equivale a 5%), no un porcentaje.

## 6. Metadatos del resultado

Cada descarga exitosa muestra fuente, período, frecuencia y una línea por serie
con nombre, código y título oficial. Para inspeccionar los metadatos guardados:

```stata
describe
char list
return list
```

Los títulos oficiales se usan como etiquetas de variables. Los códigos y
títulos completos se conservan en características de variables y del dataset.
Use el prefijo `quietly` si no desea imprimir el resumen.

## 7. Caché y actualización del catálogo

```stata
usebcch search "IPC", frequency(monthly) cache clear
usebcch search "IPC", frequency(monthly) cache refresh clear
usebcch cache status
usebcch cache clear
```

El caché vive bajo el directorio `PERSONAL` de Stata. Limpiarlo no borra el
archivo de credenciales ni su registro.

## 8. Problemas frecuentes

- `define BCCH_USER and BCCH_PASSWORD`: registre el `.env` con `usebcch auth
  set` y compruebe `usebcch auth status`.
- `variable date not found`: desde la versión 0.3 la variable temporal se llama
  `time`, igual que en `usebcrp`.
- Primeros períodos faltantes después de `variation(#)`: son el rezago necesario
  para calcular la variación, no un fallo de descarga.
- `invalid name` en una búsqueda: encierre todo el texto entre comillas rectas.
- Serie inexistente: búsquela nuevamente en el catálogo o use `skipinvalid` al
  pedir varias series.
- Datos abiertos en memoria: agregue `clear` solo si acepta reemplazarlos.

Esta biblioteca es independiente y no constituye un producto oficial del Banco
Central de Chile.

## Autor

Maykol Medrano  
Pontificia Universidad Católica de Chile  
Email: [mmedrano2@uc.cl](mailto:mmedrano2@uc.cl)  
GitHub: [MaykolMedrano](https://github.com/MaykolMedrano)
