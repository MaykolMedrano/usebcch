# Registro de cambios

## 0.4.0 - 2026-07-22

- Se estandarizó el eje temporal de salida como `time`, con `%td`, `%tm`, `%tq`
  o `%ty` según la frecuencia final.
- Se añadió el registro persistente del archivo de credenciales mediante
  `usebcch auth`.
- Se añadieron resúmenes compactos de descarga con códigos y títulos oficiales.
- Se conservaron fuente, códigos, títulos, frecuencia, formato y hora de
  consulta en resultados, etiquetas y características del conjunto de datos.
- Se reorganizó `help usebcch` como un manual completo en español, con
  instalación, credenciales, opciones, esquema de salida, metadatos, ejemplos
  y solución de problemas.
- Se acortaron las etiquetas visibles cuando los títulos BDE contienen `\`
  como separador jerárquico, conservando el título completo en los metadatos.
- Se añadieron pruebas offline, de instalación, actualización, seguridad y API.

## 0.2.0 - 2026-07-22

- Se añadió conversión nativa de frecuencia, agregación, variación, caché del
  catálogo, búsqueda con expresiones regulares y manejo de series inválidas.

## 0.1.0 - 2026-07-22

- Cliente nativo inicial para Stata/Mata basado en el comportamiento público de
  `bcchapi`.
