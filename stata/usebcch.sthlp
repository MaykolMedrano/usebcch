{smcl}
{* *! usebcch 0.4.0 22jul2026}{...}
{vieweralsosee "Portal BDE/SI3" "https://si3.bcentral.cl/siete"}{...}
{vieweralsosee "Sitio de la API BDE" "https://si3.bcentral.cl/estadisticas/Principal1/Web_Services/index.htm"}{...}
{title:Título}

{phang}
{bf:usebcch} {hline 2} Descargar y buscar series de la Base de Datos
Estadísticos (BDE) del Banco Central de Chile{p_end}

{title:Descripción}

{pstd}
{cmd:usebcch} es un cliente nativo para Stata 16 o superior. Descarga una o
varias series, busca códigos en el catálogo, convierte frecuencias, calcula
variaciones y administra un caché persistente. No requiere Python. La API del
BCCh sí requiere usuario y contraseña.{p_end}

{pstd}
Los cuatro subcomandos son {cmd:get}, {cmd:search}, {cmd:cache} y {cmd:auth}.
Los datos solo se reemplazan cuando la operación termina correctamente y se ha
especificado {opt clear}.{p_end}

{title:Inicio rápido}

{pstd}
Registre una vez la ubicación de un archivo privado `.env`:{p_end}

{phang2}{cmd:. usebcch auth set, envfile("C:/credenciales/bcch.env")}{p_end}
{phang2}{cmd:. usebcch auth status}{p_end}

{pstd}
Busque el código de una serie y luego descárguela:{p_end}

{phang2}{cmd:. usebcch search "tipo de cambio", frequency(daily) clear}{p_end}
{phang2}{cmd:. usebcch get F073.TCO.PRE.Z.D, from(2024-01-01) to(2024-12-31) clear}{p_end}

{title:Instalación y actualización}

{pstd}
Para instalar desde el repositorio público:{p_end}

{phang2}{cmd:. net install usebcch, from("https://raw.githubusercontent.com/MaykolMedrano/usebcch/main/stata") replace}{p_end}

{pstd}
Para desarrollo local, sustituya la URL por la carpeta {cmd:stata/}. En ambos
casos, {opt from()} debe apuntar al directorio exacto que contiene {cmd:stata.toc}
y {cmd:usebcch.pkg}, no a una página HTML ni a un ZIP.{p_end}

{title:Sintaxis}

{p 8 16 2}
{cmd:usebcch get} {it:códigos_de_serie}
[{cmd:,} {opt from(fecha)} {opt to(fecha)} {opt names(nombres)} {opt long}
{opt frequency(frecuencia)} {opt aggregate(funciones)} {opt variation(#)}
{opt skipinvalid} {opt clear} {opt credentials(archivo)}
{opt envfile(archivo)}]

{p 8 16 2}
{cmd:usebcch search} {it:"texto"}
[{cmd:,} {opt frequency(frecuencia)} {opt language(idioma)} {opt regex}
{opt cache} {opt refresh} {opt clear} {opt credentials(archivo)}
{opt envfile(archivo)}]

{p 8 16 2}
{cmd:usebcch cache} {cmd:status}|{cmd:clear}

{p 8 16 2}
{cmd:usebcch auth set}{cmd:,} {opt envfile(archivo)}

{p 8 16 2}
{cmd:usebcch auth} {cmd:status}|{cmd:clear}

{title:Credenciales}

{pstd}
Antes del primer llamado, cada usuario debe crear o activar su propia cuenta
en el {browse "portal BDE/SI3" "https://si3.bcentral.cl/siete"}; seleccione
{bf:Registrarse}. Los usuarios existentes pueden elegir {bf:Usuario Registrado}
o {bf:Recuperar Contraseña}. {cmd:usebcch} no crea cuentas ni entrega usuarios
o contraseñas.{p_end}

{pstd}
El método recomendado es guardar las credenciales en un archivo privado, por
ejemplo {cmd:C:/credenciales/bcch.env}:{p_end}

{phang2}{cmd:BCCH_USER=mi_usuario}{p_end}
{phang2}{cmd:BCCH_PASSWORD=mi_contraseña}{p_end}

{pstd}
{cmd:usebcch auth set, envfile(...)} registra solamente la ruta del archivo
bajo el directorio PERSONAL de Stata. No copia ni guarda el usuario o la
contraseña. {cmd:auth clear} elimina el registro, pero no borra el `.env`.
Nunca incorpore el archivo secreto a un repositorio.{p_end}

{pstd}
Las fuentes se evalúan en este orden: {opt credentials()}, {opt envfile()}, el
par de variables de entorno {cmd:BCCH_USER}/{cmd:BCCH_PASSWORD}, un `.env` en el
directorio de trabajo y, finalmente, el archivo registrado mediante
{cmd:auth set}. {opt credentials()} y {opt envfile()} no pueden combinarse.
{opt credentials()} lee usuario y contraseña desde la primera y segunda línea
de un archivo de texto.{p_end}

{title:Opciones de get}

{phang}
{opt from(fecha)} y {opt to(fecha)} delimitan la solicitud. Use exactamente el
formato ISO {cmd:YYYY-MM-DD}, por ejemplo {cmd:from(2020-01-01)}.{p_end}

{phang}
{opt names(nombres)} asigna nombres Stata en el mismo orden que los códigos.
Debe suministrarse uno por serie. Sin esta opción se crean {cmd:series1},
{cmd:series2}, etc. Los nombres finales deben ser válidos y únicos.{p_end}

{phang}
{opt long} solicita formato largo. Sin esta opción el resultado es ancho.
Las transformaciones de frecuencia y variación solo están disponibles en
formato ancho.{p_end}

{phang}
{opt frequency(frecuencia)} define la frecuencia final: {cmd:daily},
{cmd:monthly}, {cmd:quarterly} o {cmd:annual}. La variable temporal se llama
siempre {cmd:time}.{p_end}

{phang}
{opt aggregate(funciones)} es obligatorio al reducir la frecuencia. Acepta
{cmd:mean}, {cmd:last}, {cmd:first}, {cmd:sum}, {cmd:min} y {cmd:max}. Indique
una función para todas las series o una por serie, en el mismo orden.{p_end}

{phang}
{opt variation(#)} reemplaza cada valor por
{it:valor_actual/valor_rezagado - 1}. El rezago se mide en períodos exactos de
la frecuencia final y se calcula después de agregar. El resultado es una
fracción: 0.05 equivale a 5 por ciento.{p_end}

{phang}
{opt skipinvalid} omite códigos de serie inexistentes cuando se solicitan
varias series. Los errores de credenciales, red o respuesta malformada siguen
deteniendo la operación. Los códigos omitidos quedan en
{cmd:r(failed_series)}.{p_end}

{phang}
{opt clear} autoriza reemplazar el dataset en memoria. Si hay datos abiertos y
no se especifica {opt clear}, el comando se detiene para protegerlos.{p_end}

{phang}
{opt credentials(archivo)} y {opt envfile(archivo)} seleccionan explícitamente
una fuente de credenciales para esa llamada.{p_end}

{title:Opciones de search}

{phang}
El texto de búsqueda que contiene espacios o acentos debe escribirse entre
comillas rectas, por ejemplo {cmd:usebcch search "inflación subyacente"}.
La búsqueda literal no distingue mayúsculas y minúsculas.{p_end}

{phang}
{opt frequency(frecuencia)} acepta {cmd:all}, {cmd:daily}, {cmd:monthly},
{cmd:quarterly} o {cmd:annual}; el valor predeterminado es {cmd:all}.{p_end}

{phang}
{opt language(idioma)} busca en títulos {cmd:es} o {cmd:en}; el valor
predeterminado es {cmd:es}.{p_end}

{phang}
{opt regex} interpreta la consulta como expresión regular Unicode sin distinguir
mayúsculas y minúsculas. Sin {opt regex}, la consulta es texto literal.{p_end}

{phang}
{opt cache} utiliza o crea un catálogo persistente por frecuencia bajo PERSONAL.
{opt refresh} vuelve a descargar y reemplaza el catálogo seleccionado; implica
{opt cache}.{p_end}

{title:Datos producidos}

{pstd}
En formato ancho, {cmd:get} deja {cmd:time} y una variable numérica por serie.
En formato largo deja {cmd:time}, {cmd:series_id}, {cmd:value}, {cmd:status},
{cmd:value_raw}, {cmd:spanish_name} y {cmd:english_name}.{p_end}

{pstd}
La escala y el formato de {cmd:time} corresponden a la frecuencia final:
{cmd:%td} diaria, {cmd:%tm} mensual, {cmd:%tq} trimestral y {cmd:%ty} anual.
Por ello puede usarse directamente {cmd:tsset time}. Versiones de desarrollo
anteriores a 0.3 llamaban {cmd:date} a esta variable.{p_end}

{pstd}
Con {opt variation(12)}, las primeras 12 observaciones son faltantes por
definición: todavía no existe un período comparable 12 unidades atrás. Los
huecos del calendario no se puentean. Estos faltantes no indican una descarga
fallida.{p_end}

{pstd}
{cmd:search} deja {cmd:series_id}, {cmd:frequency}, {cmd:spanish_title},
{cmd:english_title}, {cmd:first_observation}, {cmd:last_observation},
{cmd:updated_at} y {cmd:created_at}. Las últimas cuatro fechas usan escala diaria
de Stata y se muestran como {cmd:YYYY-MM-DD}.{p_end}

{title:Metadatos}

{pstd}
Una descarga exitosa imprime fuente, período, frecuencia, diseño y una línea por
serie con nombre de salida, código y título oficial. Use
{cmd:quietly usebcch get ...} para suprimir ese resumen.{p_end}

{pstd}
En formato ancho, los títulos oficiales son etiquetas de variables. El código y
los títulos completos en español e inglés quedan como características de cada
variable. La fuente, fecha de recuperación, códigos, frecuencia, diseño y
agregación quedan como características del dataset. Inspeccione todo con:{p_end}

{pstd}
El BDE puede entregar un título jerárquico con separadores {cmd:\}. Para evitar
etiquetas y resúmenes innecesariamente largos, {cmd:usebcch} muestra solo el
primer segmento anterior a {cmd:\}. El título oficial completo se conserva en
{cmd:usebcch_title_es}, {cmd:usebcch_title_en}, {cmd:spanish_name},
{cmd:english_name} y en los resultados {cmd:r(title_es#)} y
{cmd:r(title_en#)}.{p_end}

{phang2}{cmd:. describe}{p_end}
{phang2}{cmd:. char list}{p_end}
{phang2}{cmd:. return list}{p_end}

{title:Caché y autenticación}

{phang2}{cmd:. usebcch cache status}{p_end}
{phang2}{cmd:. usebcch cache clear}{p_end}
{phang2}{cmd:. usebcch auth status}{p_end}
{phang2}{cmd:. usebcch auth clear}{p_end}

{pstd}
Limpiar el caché elimina únicamente catálogos propiedad de {cmd:usebcch}. No
borra el `.env` ni su registro. Limpiar la autenticación elimina el registro de
la ruta, pero tampoco borra el archivo secreto.{p_end}

{title:Resultados guardados}

{pstd}
{cmd:get} guarda {cmd:r(N)}, {cmd:r(layout)}, {cmd:r(successful_series)},
{cmd:r(failed_series)}, {cmd:r(frequency)}, {cmd:r(aggregate)},
{cmd:r(variation)}, {cmd:r(source)}, {cmd:r(series_codes)}, {cmd:r(names)},
{cmd:r(period_start)} y {cmd:r(period_end)}. Para cada serie exitosa también
guarda {cmd:r(code#)}, {cmd:r(name#)}, {cmd:r(title_es#)} y
{cmd:r(title_en#)}.{p_end}

{pstd}
{cmd:search} guarda {cmd:r(N)}, {cmd:r(cache_hits)} y {cmd:r(downloads)}.
{cmd:cache} guarda {cmd:r(N)}, {cmd:r(frequencies)} y {cmd:r(cache_dir)}.
{cmd:auth} guarda {cmd:r(configured)}, {cmd:r(valid)}, {cmd:r(action)},
{cmd:r(envfile)} y {cmd:r(config_file)} cuando corresponda.{p_end}

{title:Ejemplos}

{phang2}{cmd:. usebcch get F073.TCO.PRE.Z.D, from(2024-01-01) clear}{p_end}

{phang2}{cmd:. usebcch get F073.TCO.PRE.Z.D F022.TPM.TIN.D001.NO.Z.D, names(dolar tpm) from(2024-01-01) clear}{p_end}

{phang2}{cmd:. usebcch get F073.TCO.PRE.Z.D, names(dolar) from(2020-01-01) frequency(monthly) aggregate(mean) variation(12) clear}{p_end}

{phang2}{cmd:. usebcch search "IPC", frequency(monthly) language(es) cache clear}{p_end}

{phang2}{cmd:. usebcch search "^ipc.*subyacente", frequency(monthly) regex cache clear}{p_end}

{title:Problemas frecuentes}

{phang}
{bf:Mensaje sobre BCCH_USER y BCCH_PASSWORD:} ejecute {cmd:usebcch auth status};
si no hay una configuración válida, registre el `.env` mediante
{cmd:usebcch auth set, envfile("ruta")}.{p_end}

{phang}
{bf:variable date not found:} use {cmd:time}. Ambos paquetes emplean ese nombre
para un eje temporal homogéneo.{p_end}

{phang}
{bf:invalid name durante search:} cierre la consulta completa con comillas
rectas antes de escribir la coma de opciones.{p_end}

{phang}
{bf:Valores iniciales faltantes:} después de {opt variation(#)} corresponden al
rezago requerido y son esperados.{p_end}

{title:Requisitos y licencia}

{pstd}
Requiere Stata 16 o superior y acceso HTTPS. Paquete independiente basado en el
comportamiento público de la biblioteca MIT {cmd:bcchapi}; no es un producto
oficial del Banco Central de Chile. Licencia MIT.{p_end}

{marker author}{...}
{title:Author}

{pstd}
Maykol Medrano
{break}Pontificia Universidad Católica de Chile
{break}Email: mmedrano2@uc.cl
{break}GitHub: {browse "https://github.com/MaykolMedrano":MaykolMedrano}
