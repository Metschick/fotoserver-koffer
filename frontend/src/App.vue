<script setup lang="ts">
import NavBar from '@/components/NavBar.vue'
import { useTheme } from '@/composables/useTheme'

// Theme-Singleton aktivieren – stellt Reaktivität für alle Kind-Komponenten sicher
useTheme()
</script>

<template>
  <div class="min-h-screen bg-gray-50 dark:bg-gray-900 text-gray-900 dark:text-gray-100 transition-colors duration-200">
    <NavBar />
    <main class="container mx-auto px-4 py-8">
      <RouterView />
    </main>
  </div>
</template>
