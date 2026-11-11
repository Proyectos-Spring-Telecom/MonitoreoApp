'use strict';

// Pantalla de carga, service worker y aviso de versión nueva. Está en un
// archivo aparte (y no dentro de index.html) para que la política de
// seguridad (CSP) pueda prohibir los scripts en línea.
(function () {
  // `tool/build_web.sh` reemplaza __BUILD_ID__ por el número de compilación.
  // Sin él (p. ej. `flutter run`), no se registra el service worker.
  var BUILD_ID = '__BUILD_ID__';
  var stamped = BUILD_ID.indexOf('__') !== 0;

  // Revisa si hay una versión nueva cada 30 minutos y al volver a la app.
  var CHECK_EVERY_MS = 30 * 60 * 1000;

  window.addEventListener('flutter-first-frame', function () {
    hideSplash();
    cacheLoadedFiles();
  });

  if (!stamped || !('serviceWorker' in navigator)) return;

  window.addEventListener('load', function () {
    navigator.serviceWorker.register('sw.js').catch(function (error) {
      console.warn('No se pudo registrar el service worker:', error);
    });
  });

  document.addEventListener('visibilitychange', function () {
    if (document.visibilityState === 'visible') checkForUpdate();
  });
  setInterval(checkForUpdate, CHECK_EVERY_MS);

  function hideSplash() {
    var splash = document.getElementById('splash');
    if (!splash) return;
    splash.classList.add('hidden');
    setTimeout(function () {
      splash.remove();
    }, 400);
  }

  // En la primera visita la app descarga todo antes de que el service worker
  // tome el control; se le pasa la lista para que lo guarde.
  function cacheLoadedFiles() {
    if (!stamped || !('serviceWorker' in navigator)) return;
    navigator.serviceWorker.ready.then(function (registration) {
      if (!registration.active) return;
      var urls = performance.getEntriesByType('resource').map(function (entry) {
        return entry.name;
      });
      urls.push(location.href.split('#')[0]);
      registration.active.postMessage({ type: 'cache-urls', urls: urls });
    });
  }

  function checkForUpdate() {
    fetch('build.json', { cache: 'no-store' })
      .then(function (response) {
        return response.ok ? response.json() : null;
      })
      .then(function (data) {
        if (data && data.build && data.build !== BUILD_ID) showUpdateBanner();
      })
      .catch(function () {
        // Sin conexión: se revisa la próxima vez.
      });
  }

  function showUpdateBanner() {
    var banner = document.getElementById('update-banner');
    if (!banner || !banner.hidden) return;
    banner.hidden = false;
    document.getElementById('update-reload').addEventListener('click', function () {
      // La red va primero, así que recargar trae la versión nueva.
      location.reload();
    });
    document.getElementById('update-later').addEventListener('click', function () {
      banner.hidden = true;
    });
  }
})();
