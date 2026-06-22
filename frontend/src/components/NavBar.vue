<script setup lang="ts">
import { useTheme } from '@/composables/useTheme'

const { theme, toggleTheme } = useTheme()
</script>

<template>
  <header class="bg-white dark:bg-gray-800 border-b border-gray-200 dark:border-gray-700 shadow-sm">
    <nav class="container mx-auto px-4 h-14 flex items-center justify-between">

      <!-- Logo / Titel -->
      <RouterLink
        to="/"
        class="flex items-center gap-2 font-semibold text-gray-900 dark:text-gray-100 hover:text-blue-600 dark:hover:text-blue-400 transition-colors"
      >
        <!-- Kamera-Icon -->
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-5 h-5">
          <path d="M12 9a3.75 3.75 0 100 7.5A3.75 3.75 0 0012 9z" />
          <path fill-rule="evenodd" d="M9.344 3.071a49.52 49.52 0 015.312 0c.967.052 1.83.585 2.332 1.39l.821 1.317c.24.383.645.643 1.11.71.386.054.77.113 1.152.177 1.432.239 2.429 1.493 2.429 2.909V18a3 3 0 01-3 3h-15a3 3 0 01-3-3V9.574c0-1.416.997-2.67 2.429-2.909.382-.064.766-.123 1.151-.178a1.56 1.56 0 001.11-.71l.822-1.315a2.942 2.942 0 012.332-1.39zM6.75 12.75a5.25 5.25 0 1110.5 0 5.25 5.25 0 01-10.5 0zm12-1.5a.75.75 0 100-1.5.75.75 0 000 1.5z" clip-rule="evenodd" />
        </svg>
        Fotoserver-Koffer
      </RouterLink>

      <!-- Navigation + Theme-Toggle -->
      <div class="flex items-center gap-1">
        <RouterLink
          to="/upload"
          active-class="text-blue-600 dark:text-blue-400 bg-blue-50 dark:bg-blue-900/30"
          class="px-3 py-1.5 rounded-md text-sm text-gray-600 dark:text-gray-300 hover:text-blue-600 dark:hover:text-blue-400 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
        >
          Hochladen
        </RouterLink>

        <RouterLink
          to="/galerie"
          active-class="text-blue-600 dark:text-blue-400 bg-blue-50 dark:bg-blue-900/30"
          class="px-3 py-1.5 rounded-md text-sm text-gray-600 dark:text-gray-300 hover:text-blue-600 dark:hover:text-blue-400 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
        >
          Galerie
        </RouterLink>

        <!-- Theme-Toggle -->
        <button
          type="button"
          @click="toggleTheme"
          :aria-label="theme === 'dark' ? 'Zu Hell-Modus wechseln' : 'Zu Dunkel-Modus wechseln'"
          class="ml-2 p-2 rounded-md text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
        >
          <!-- Sonne: aktuell dunkel → zu hell wechseln -->
          <svg v-if="theme === 'dark'" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-5 h-5">
            <path d="M12 2.25a.75.75 0 01.75.75v2.25a.75.75 0 01-1.5 0V3a.75.75 0 01.75-.75zM7.5 12a4.5 4.5 0 119 0 4.5 4.5 0 01-9 0zM18.894 6.166a.75.75 0 00-1.06-1.06l-1.591 1.59a.75.75 0 101.06 1.061l1.591-1.59zM21.75 12a.75.75 0 01-.75.75h-2.25a.75.75 0 010-1.5H21a.75.75 0 01.75.75zM17.834 18.894a.75.75 0 001.06-1.06l-1.59-1.591a.75.75 0 10-1.061 1.06l1.59 1.591zM12 18a.75.75 0 01.75.75V21a.75.75 0 01-1.5 0v-2.25A.75.75 0 0112 18zM7.166 17.834a.75.75 0 00-1.06 1.06l1.59 1.591a.75.75 0 001.061-1.06l-1.59-1.591zM6 12a.75.75 0 01-.75.75H3a.75.75 0 010-1.5h2.25A.75.75 0 016 12zM6.166 7.166a.75.75 0 00-1.06-1.06l-1.59 1.59a.75.75 0 001.06 1.061l1.59-1.59z" />
          </svg>
          <!-- Mond: aktuell hell → zu dunkel wechseln -->
          <svg v-else xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-5 h-5">
            <path fill-rule="evenodd" d="M9.528 1.718a.75.75 0 01.162.819A8.97 8.97 0 009 6a9 9 0 009 9 8.97 8.97 0 003.463-.69.75.75 0 01.981.98 10.503 10.503 0 01-9.694 6.46c-5.799 0-10.5-4.701-10.5-10.5 0-4.368 2.667-8.112 6.46-9.694a.75.75 0 01.818.162z" clip-rule="evenodd" />
          </svg>
        </button>
      </div>

    </nav>
  </header>
</template>
