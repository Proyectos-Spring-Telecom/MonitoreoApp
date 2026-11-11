{{flutter_js}}
{{flutter_build_config}}

// Sin `serviceWorkerSettings`: el service worker de Flutter es obsoleto (se
// da de baja solo) y reemplazaría al de la app (`sw.js`, registrado en
// `pwa.js`).
_flutter.loader.load();
