{{flutter_js}}
{{flutter_build_config}}

// Older offline builds may still be controlled by Flutter's retired service
// worker. Version the entry point so the new app is fetched on this first load.
const appVersion = new URL(document.currentScript.src).searchParams.get('v');
if (appVersion) {
  for (const build of _flutter.buildConfig.builds) {
    if (build.mainJsPath) build.mainJsPath += '?v=' + encodeURIComponent(appVersion);
  }
}
(async () => {
  if ('serviceWorker' in navigator) {
    try {
      const registrations = await navigator.serviceWorker.getRegistrations();
      for (const registration of registrations) {
        const worker = registration.active || registration.waiting;
        if (worker && new URL(worker.scriptURL).pathname.endsWith('/flutter_service_worker.js')) {
          await registration.unregister();
          // These caches contain generated assets only; saved progress stays
          // in local preferences and is not removed.
          for (const name of ['flutter-app-cache', 'flutter-temp-cache', 'flutter-app-manifest']) {
            await caches.delete(name);
          }
        }
      }
    } catch (_) { /* Loading the app must work if worker cleanup is unavailable. */ }
  }
  _flutter.loader.load();
})();
