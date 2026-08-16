# Especificación de compatibilidad con `bcchapi` 1.1.2

Esta especificación se deriva del código fuente publicado de `bcchapi` 1.1.2. Los
fixtures son respuestas representativas y deliberadamente sintéticas: fijan la
estructura y los casos límite sin afirmar que sus textos de `Descripcion` sean
literales del servicio del Banco Central.

## Transporte y solicitudes

El endpoint REST publicado es
`https://si3.bcentral.cl/SieteRestWS/SieteRestWS.ashx`. Todas las operaciones
son solicitudes HTTPS GET con parámetros en la query.

La documentación pública describe `user` y `pass` como credenciales activadas
para la cuenta BDE. Algunas cuentas pueden ofrecer un API Key Token; `usebcch`
lo acepta desde `BCCH_TOKEN` o `APIKEY` como parámetro `token` y prioriza ese método cuando está disponible. El formato
heredado continúa soportado.

`GetSeries` envía estos parámetros conceptuales:

| Parámetro | Valor |
|---|---|
| `token` | API Key Token, si la cuenta lo entrega |
| `user` | usuario BDE heredado |
| `pass` | contraseña BDE heredada |
| `firstdate` | fecha inicial opcional |
| `lastdate` | fecha final opcional |
| `timeseries` | identificador de serie |
| `function` | `GetSeries` |

Si `firstdate` o `lastdate` no se especifican, se omiten de la query para que
el servidor aplique sus límites predeterminados.

`SearchSeries` reemplaza fechas y serie por `frequency` y envía
`function=SearchSeries`. Las frecuencias admitidas son `DAILY`, `MONTHLY`,
`QUARTERLY` y `ANNUAL`.

La implementación Stata codifica tokens y credenciales con URL encoding y
nunca los muestra en mensajes. Debe distinguir errores HTTP/de red de una
respuesta JSON válida con `Codigo != 0`. El BCCh limita a cinco series por
segundo por cuenta, independientemente de la dirección IP.
## Sobre de respuesta

`bcchapi.WSResponse` exige cuatro claves de nivel superior, con coincidencia
exacta de mayúsculas:

- `Codigo`: entero.
- `Descripcion`: texto.
- `Series`: objeto con datos de `GetSeries` (campos nulos conceptualmente en una
  búsqueda).
- `SeriesInfos`: lista con catálogo de `SearchSeries` (vacía en una descarga).

El constructor Python fallaría si falta cualquiera de ellas o si llegan claves
adicionales, porque ejecuta `WSResponse(**json)`. La implementación Stata debería
aceptar claves adicionales para tolerar ampliaciones del servicio, pero tratar
como respuesta malformada la ausencia o tipo inválido de campos indispensables.

## `GetSeries`

Con `Codigo == 0`, `Series` contiene:

- `descripEsp`, `descripIng`, `seriesId`: textos.
- `Obs`: lista ordenada de observaciones.
- Cada observación contiene `indexDateString`, `value` y `statusCode`.

La conversión de `GSResponse.to_series()` aplica `pandas.to_datetime(...,
dayfirst=True)` a las fechas y `float(value)` a cada valor. Por tanto:

- `indexDateString` se interpreta día primero; el fixture usa `DD-MM-YYYY`.
- El separador decimal esperado es punto, independientemente de la configuración
  regional de Stata.
- `"NaN"` se convierte en faltante numérico; `statusCode` se descarta en la
  conversión de Python.
- Un valor no convertible por `float()` hace fallar toda la conversión.
- Una lista `Obs` vacía es válida y produce una serie/dataset sin filas.
- Se conserva el orden de observaciones recibido; no hay ordenamiento ni control
  de fechas duplicadas en `bcchapi`.

Para equivalencia práctica, Stata produce un eje numérico `time`, valor
numérico y conserva `statusCode` cuando el formato de salida lo permita. El eje
usa `%td`, `%tm`, `%tq` o `%ty` según la frecuencia final. Debe
mapear `NaN` a `.`. Es recomendable mapear otros tokens no numéricos (`ND`, vacío
o `null`) a faltante con advertencia, en lugar de reproducir el fallo abrupto de
Python. Esto es una mejora intencional y debe probarse aparte cuando existan
fixtures capturados del servicio.

Fechas de entrada con método `strftime` se transforman a `YYYY-MM-DD`; las
cadenas se envían sin validación local. Cadena vacía significa límite omitido.
La documentación de `bcchapi` dice erróneamente que `last_date` vacío usa la
primera observación; el comportamiento real se delega al servidor y normalmente
representa el último dato disponible.

## `SearchSeries`

Cada elemento de `SeriesInfos` contiene ocho campos:

1. `seriesId`
2. `frequencyCode`
3. `spanishTitle`
4. `englishTitle`
5. `firstObservation`
6. `lastObservation`
7. `updatedAt`
8. `createdAt`

`SSResponse.to_df()` convierte los últimos cuatro campos con formato estricto
`%d-%m-%Y` y `errors="coerce"`: texto vacío o fecha inválida se convierte en
fecha faltante sin abortar. Los demás campos permanecen como texto. Una lista
vacía debe dar un dataset vacío con un esquema estable en Stata, aunque pandas
no crea columnas para un `DataFrame([])` antes de intentar convertirlas (un caso
en que `bcchapi` puede lanzar `KeyError`).

Los títulos pueden contener acentos, eñes, puntuación y caracteres Unicode; no
deben sufrir pérdida de codificación.

## Errores del servicio

El significado de `Codigo` depende de la operación:

| Código | Contexto | Excepción en `bcchapi` | Comportamiento Stata esperado |
|---:|---|---|---|
| `-5` | cualquiera | `InvalidCredentials` | error de credenciales |
| `-50` | `GetSeries` | `InvalidSeries` | serie inexistente |
| `-1` | `GetSeries` | `InvalidDate` | fecha inválida |
| `-1` | `SearchSeries` | `InvalidFrequency` | frecuencia inválida |

La detección de `-5` ocurre antes de convertir a respuesta específica. Otros
códigos negativos no reciben manejo especial en 1.1.2 y podrían llegar a la
conversión como si fueran éxito. Stata debe considerar cualquier `Codigo != 0`
un error del servicio, preservando `Codigo` y `Descripcion`; la tabla anterior
define los mensajes especializados conocidos.

Los dos fixtures con `Codigo == -1` son estructuralmente iguales salvo por
`Descripcion`; el parser no debe inferir el tipo de error desde ese texto, sino
desde la operación que originó la respuesta.

## Tablas de varias series (`Stat.table` / `Siete.cuadro`)

- Una cadena de series elimina todos los espacios y se separa por comas.
- Un diccionario usa valores como IDs y claves como nombres finales.
- Los elementos no textuales producen `TypeError` antes de descargar.
- Las series se descargan secuencialmente y se concatenan por unión exterior de
  fechas.
- Se restaura el orden solicitado de columnas.
- Por defecto, una serie inválida aborta. Con `stop_invalid=False` se omite; si
  ninguna es válida se produce error.
- `names` se combina con IDs mediante `zip`: la implementación Python no exige
  igual longitud, pese a que la documentación sí lo afirma.
- Al cambiar frecuencia, `observed` es obligatorio. La agregación se delega a
  `resample().aggregate()`.
- Una variación entera `n` usa desplazamiento calendario de `n` meses, no
  simplemente `n` filas. Luego calcula cambio fraccional `(x/x_pasado)-1`, no
  porcentaje multiplicado por 100.

La implementación actual incluye agregación y variación. A diferencia de la
versión Python histórica, `variation(#)` usa periodos exactos de la frecuencia
final, el mismo contrato temporal que `usebcrp`.

## Búsqueda de catálogo (`browse` / `buscar`)

La versión Python descarga las cuatro frecuencias en el orden de iteración de
un `set`, que no es estable, concatena catálogos y opcionalmente guarda caché en
memoria. La búsqueda usa una expresión regular de pandas, sin distinguir
mayúsculas. `Stat.browse` busca inglés por defecto; `Siete.buscar` busca español
por defecto. No se eliminan duplicados.

Stata impone un orden determinista (`DAILY`, `MONTHLY`, `QUARTERLY`, `ANNUAL`),
ofrece búsqueda literal o `regex`, y puede mantener caché persistente.

## Matriz mínima de pruebas

| Fixture | Verificación principal |
|---|---|
| `getseries_ok.json` | metadatos, fecha día-primero, decimal con punto, `NaN`, Unicode y estado |
| `getseries_empty.json` | éxito sin observaciones |
| `searchseries_ok.json` | ocho campos, fechas válidas e inválidas, Unicode |
| `error_invalid_credentials.json` | `-5` independiente de operación |
| `error_invalid_series.json` | `-50` en `GetSeries` |
| `error_invalid_date.json` | `-1` interpretado según `GetSeries` |
| `error_invalid_frequency.json` | `-1` interpretado según `SearchSeries` |

Además deben simularse sin fixture JSON: HTTP 401/403/500, timeout, cuerpo no
JSON, JSON truncado, campos requeridos ausentes, tipo inesperado, observaciones
duplicadas y respuesta con claves futuras desconocidas.
