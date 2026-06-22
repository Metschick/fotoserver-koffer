// Sofortige Theme-Initialisierung — verhindert FOUC (kurzes Aufblitzen des falschen Themes).
// Dieses Skript wird synchron (kein defer/async) geladen, damit die dark-Klasse
// gesetzt ist, bevor der Browser das erste Frame rendert.
// Ausgelagert aus index.html damit Content-Security-Policy ohne 'unsafe-inline' auskommt.
;(function () {
  var stored = localStorage.getItem('fotoserver-theme')
  var prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
  if (stored === 'dark' || (!stored && prefersDark)) {
    document.documentElement.classList.add('dark')
  }
})()
