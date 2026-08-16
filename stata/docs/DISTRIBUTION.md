# Distribución de `usebcch`

Este documento distingue el repositorio de desarrollo, la carpeta preparada
para validación y el ZIP final. El script no crea un ZIP de manera automática.

## Estructura del repositorio

La subcarpeta `stata/` es el sitio `net install` válido. Stata necesita
encontrar allí `stata.toc`, `usebcch.pkg` y todos los archivos declarados en el
manifiesto; la raíz queda reservada para documentación y desarrollo.

```text
usebcch/
  stata/                 sitio instalable de Stata
    stata.toc            índice del sitio Stata
    usebcch.pkg          manifiesto de instalación y versión
    usebcch.ado          comando público e implementación ado
    usebcch_json.mata    parser JSON nativo
    usebcch_core.mata    núcleo de respuesta y materialización
    usebcch.sthlp        ayuda accesible con help usebcch
  README.md              presentación y referencia rápida
  CHANGELOG.md           historia de versiones
  LICENSE                licencia y atribución
  stata/docs/            guías y especificación técnica
  stata/scripts/          automatización de pruebas y distribución
  stata/tests/            pruebas deterministas y pruebas live optativas
  artifacts/             logs generados; ignorados por Git
  dist/                  releases preparados; ignorados por Git
```

Los archivos de ejecución están agrupados en `stata/`; `.env`, logs, fixtures,
pruebas y documentación no forman parte del manifiesto instalable.

## Fuente única del contenido distribuible

`usebcch.pkg` declara los archivos instalables con líneas `f`. El script de
release lee esas líneas y la declaración `d Version` directamente; no mantiene una
segunda lista manual de archivos de ejecución que pueda quedar desactualizada.
Añade `stata/stata.toc`, el propio manifiesto, la documentación del proyecto y
`SHA256SUMS.txt`.

Antes de preparar una versión, compruebe que coincidan:

- la versión y fecha de `usebcch.pkg`;
- la cabecera de versión de `usebcch.ado` y `usebcch.sthlp`;
- la entrada correspondiente de `CHANGELOG.md`;
- los ejemplos y requisitos de `README.md`, `stata/docs/GUIA_USUARIO.md` y la ayuda.

## Flujo de publicación

### 1. Ejecutar las pruebas de desarrollo

Desde PowerShell y la raíz del proyecto:

```powershell
powershell -ExecutionPolicy Bypass -File stata/scripts/run-tests.ps1
```

El runner usa por defecto
`C:\Program Files\StataNow19\StataSE-64.exe`, espera el resultado y mueve los
logs a `artifacts/logs/<fecha-hora>/`.

### 2. Preparar una carpeta, todavía sin ZIP

```powershell
powershell -ExecutionPolicy Bypass -File stata/scripts/build-release.ps1
```

Esto crea `dist/usebcch-0.5.1/`, copia solo los archivos declarados y calcula
SHA-256. Se detiene si la carpeta ya existe para no mezclar dos construcciones.

### 3. Validar exactamente lo que se publicaría

Desde Stata, situado en la raíz del repositorio:

```stata
do stata/tests/distribution.do "dist/usebcch-0.5.1"
```

La prueba cambia `PERSONAL` dentro de ese proceso, instala desde `dist/`, busca
los archivos instalados, abre la ayuda y comprueba que no se haya distribuido
una configuración de credenciales.

Revise además `dist/usebcch-0.5.1/SHA256SUMS.txt` y confirme que no existan
`.env`, credenciales, logs ni archivos de pruebas.

### 4. Crear el ZIP únicamente después de aprobar la carpeta

El script se niega a sobrescribir la carpeta preparada. Una vez validada, cree
el ZIP de esa misma carpeta con la opción explícita:

```powershell
powershell -ExecutionPolicy Bypass -File stata/scripts/build-release.ps1 -Archive
```

El script vuelve a comprobar el manifiesto y todos los checksums antes de crear
`dist/usebcch-0.5.1.zip`. La opción `-Archive` es deliberadamente optativa para
impedir que una versión no revisada parezca final.

## Instalación para usuarios

### Cuenta BDE y credenciales

La documentación pública indica crear una cuenta BDE, activar las credenciales
de la API y aceptar los términos y condiciones. Use el usuario y contraseña
entregados por el portal. Si su cuenta muestra **Mi Cuenta > Apikey Token**,
también puede configurar `BCCH_TOKEN` o su alias `APIKEY`. SOAP mantiene usuario y contraseña.

La instalación publicada apunta al sitio raw del repositorio:

```stata
net install usebcch, ///
    from("https://raw.githubusercontent.com/MaykolMedrano/usebcch/main/stata") replace
```

Para validar una carpeta local preparada, sustituya la URL por
`C:/ruta/usebcch/stata`. En ambos casos, `from()` debe señalar el directorio
exacto donde estén `stata.toc` y `usebcch.pkg`, no la página HTML del
repositorio ni el ZIP.

La API permite como máximo cinco series por segundo por cuenta,
independientemente de la dirección IP. Respete este límite durante las pruebas
y la distribución.
## Secretos

`.env` está ignorado por Git y no figura en `usebcch.pkg`; por tanto, el script
no lo copia a `dist/`. La prueba de distribución debe seguir comprobando que una
instalación nueva empiece sin credenciales configuradas.
