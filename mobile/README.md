# TicketSec Mobile (Flutter)

Esta carpeta contiene la app Flutter que consume la API Node.js de TicketSec.
Incluye acceso/registro con OTP, compra y selección de asientos, boletos con QR,
validación de QR por texto, consulta de soporte y panel administrativo.

## Requisitos para compilar Android

Instala Flutter y Android Studio en una computadora (no se compila directamente
en el teléfono). En Android Studio instala Android SDK y las herramientas de
compilación. La carpeta Android ya está generada, junto con el permiso de
Internet. Para probar en la red local se habilitó HTTP sin cifrar; antes de
publicar, configura HTTPS y elimina `android:usesCleartextTraffic` del
manifiesto. Verifica la instalación con `flutter doctor`.

## Ejecutar en el emulador Android

Inicia PostgreSQL/Redis, el backend y la pasarela desde la raíz del proyecto:

```powershell
docker compose up -d
npm run gateway
npm start
```

En otra terminal, desde `mobile\`:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

`10.0.2.2` es la dirección especial con la que el emulador Android llega al
`localhost` de la computadora. La pasarela se asume en el mismo host, puerto
`4001`.

## Ejecutar en un teléfono Android por Wi-Fi

Conecta el teléfono y la computadora a la misma red. Busca la IPv4 de la
computadora con `ipconfig`, permite los puertos TCP `3000` y `4001` en el
firewall y ejecuta:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.25:3000
```

Reemplaza `192.168.1.25` por la IPv4 real de la computadora. No uses
`localhost` ni `10.0.2.2` en un teléfono físico.

Para generar un APK de prueba:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=http://192.168.1.25:3000
```

El APK estará en `build\app\outputs\flutter-apk\app-release.apk`. Para
distribución, configura HTTPS, firma de release y una URL pública estable antes
de compilar. El backend de demostración imprime el OTP en la terminal de
`npm start` (o lo devuelve si `DEV_SHOW_OTP=1`); la app lo solicita en el paso
de verificación.

La pasarela es simulada: usa únicamente tarjetas de prueba; no ingreses datos
reales de pago.
