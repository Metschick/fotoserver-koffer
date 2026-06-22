import { ref, watch } from 'vue'

const STORAGE_KEY = 'fotoserver-theme'

type Theme = 'light' | 'dark'

function resolveInitialTheme(): Theme {
  const stored = localStorage.getItem(STORAGE_KEY)
  if (stored === 'light' || stored === 'dark') return stored
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
}

// Singleton: alle Komponenten teilen denselben Theme-Zustand
const theme = ref<Theme>(resolveInitialTheme())

function applyTheme(t: Theme): void {
  document.documentElement.classList.toggle('dark', t === 'dark')
  localStorage.setItem(STORAGE_KEY, t)
}

// Sofort anwenden (Synchronisation mit dem FOUC-Schutz-Skript im index.html)
applyTheme(theme.value)

// Bei jeder Änderung DOM aktualisieren und persistieren
watch(theme, applyTheme)

export function useTheme() {
  function toggleTheme(): void {
    theme.value = theme.value === 'dark' ? 'light' : 'dark'
  }

  return { theme, toggleTheme }
}
