<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import { type GalleryPage, type MediaRead, fetchGallery } from '@/api/media'

const emit = defineEmits<{
  open: [item: MediaRead, items: MediaRead[]]
}>()

const LIMIT = 50

const items = ref<MediaRead[]>([])
const total = ref(0)
const loading = ref(false)
const error = ref<string | null>(null)

const hasMore = computed(() => items.value.length < total.value)

let abortCtrl: AbortController | null = null

onUnmounted(() => abortCtrl?.abort())

async function load() {
  if (loading.value) return
  abortCtrl = new AbortController()
  loading.value = true
  error.value = null
  try {
    const page: GalleryPage = await fetchGallery(LIMIT, items.value.length, abortCtrl.signal)
    items.value.push(...page.items)
    total.value = page.total
  } catch (err) {
    if (err instanceof DOMException && err.name === 'AbortError') return
    error.value = err instanceof Error ? err.message : 'Fehler beim Laden der Galerie'
  } finally {
    loading.value = false
  }
}

onMounted(load)

function openItem(item: MediaRead) {
  // Shallow copy so the viewer list is a snapshot and won't grow when load() appends
  emit('open', item, [...items.value])
}

function formatDate(iso: string): string {
  return new Date(iso).toLocaleString('de-DE', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}
</script>

<template>
  <!-- Loading skeleton (initial load only) -->
  <div
    v-if="loading && !items.length"
    class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-2"
    aria-busy="true"
    aria-label="Galerie wird geladen"
  >
    <div
      v-for="n in 8"
      :key="n"
      class="aspect-square rounded-lg bg-gray-200 dark:bg-gray-700 animate-pulse"
    />
  </div>

  <!-- Error state (initial load) -->
  <div v-else-if="error && !items.length" class="text-center py-16">
    <p class="text-red-500 dark:text-red-400 mb-4">{{ error }}</p>
    <button
      type="button"
      class="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white text-sm rounded-lg transition-colors"
      @click="load"
    >
      Erneut versuchen
    </button>
  </div>

  <!-- Empty state -->
  <div v-else-if="!items.length" class="text-center py-16">
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="currentColor"
      class="w-10 h-10 mx-auto mb-4 text-gray-400 dark:text-gray-500"
    >
      <path
        fill-rule="evenodd"
        d="M1.5 6a2.25 2.25 0 012.25-2.25h16.5A2.25 2.25 0 0122.5 6v12a2.25 2.25 0 01-2.25 2.25H3.75A2.25 2.25 0 011.5 18V6zM3 16.06V18c0 .414.336.75.75.75h16.5A.75.75 0 0021 18v-1.94l-2.69-2.689a1.5 1.5 0 00-2.12 0l-.88.879.97.97a.75.75 0 11-1.06 1.06l-5.16-5.159a1.5 1.5 0 00-2.12 0L3 16.061zm10.125-7.81a1.125 1.125 0 112.25 0 1.125 1.125 0 01-2.25 0z"
        clip-rule="evenodd"
      />
    </svg>
    <p class="text-gray-500 dark:text-gray-400 mb-4">
      Noch keine Fotos oder Videos hochgeladen.
    </p>
    <RouterLink
      to="/upload"
      class="inline-flex items-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-medium rounded-lg transition-colors"
    >
      Jetzt hochladen
    </RouterLink>
  </div>

  <!-- Grid -->
  <div v-else>
    <p class="text-sm text-gray-500 dark:text-gray-400 mb-3">
      {{ total }} {{ total === 1 ? 'Datei' : 'Dateien' }}
    </p>

    <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-2">
      <button
        v-for="item in items"
        :key="item.id"
        type="button"
        :aria-label="`${item.filename} von ${item.device_name}, ${formatDate(item.uploaded_at)}`"
        class="group relative aspect-square overflow-hidden rounded-lg bg-gray-200 dark:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 focus:ring-offset-white dark:focus:ring-offset-gray-900"
        @click="openItem(item)"
      >
        <!-- Thumbnail -->
        <img
          v-if="item.thumb_path"
          :src="`/api/media/${item.id}/thumb`"
          :alt="item.filename"
          loading="lazy"
          class="w-full h-full object-cover"
        />
        <!-- Placeholder for missing thumbnail -->
        <div v-else class="w-full h-full flex items-center justify-center">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="currentColor"
            class="w-8 h-8 text-gray-400 dark:text-gray-500"
          >
            <path
              fill-rule="evenodd"
              d="M1.5 6a2.25 2.25 0 012.25-2.25h16.5A2.25 2.25 0 0122.5 6v12a2.25 2.25 0 01-2.25 2.25H3.75A2.25 2.25 0 011.5 18V6zM3 16.06V18c0 .414.336.75.75.75h16.5A.75.75 0 0021 18v-1.94l-2.69-2.689a1.5 1.5 0 00-2.12 0l-.88.879.97.97a.75.75 0 11-1.06 1.06l-5.16-5.159a1.5 1.5 0 00-2.12 0L3 16.061zm10.125-7.81a1.125 1.125 0 112.25 0 1.125 1.125 0 01-2.25 0z"
              clip-rule="evenodd"
            />
          </svg>
        </div>

        <!-- Video play overlay -->
        <div
          v-if="item.mime_type.startsWith('video/')"
          class="absolute inset-0 flex items-center justify-center pointer-events-none"
        >
          <div class="bg-black/40 rounded-full p-2.5">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              fill="currentColor"
              class="w-6 h-6 text-white"
            >
              <path
                fill-rule="evenodd"
                d="M4.5 5.653c0-1.426 1.529-2.33 2.779-1.643l11.54 6.348c1.295.712 1.295 2.573 0 3.285L7.28 19.991c-1.25.687-2.779-.217-2.779-1.643V5.653z"
                clip-rule="evenodd"
              />
            </svg>
          </div>
        </div>

        <!-- Hover info overlay -->
        <div
          class="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/60 to-transparent px-2 py-2 opacity-0 group-hover:opacity-100 group-focus:opacity-100 transition-opacity pointer-events-none"
        >
          <p class="text-white text-xs font-medium truncate">{{ item.device_name }}</p>
          <p class="text-white/75 text-xs">{{ formatDate(item.uploaded_at) }}</p>
        </div>
      </button>
    </div>

    <!-- Load more -->
    <div v-if="hasMore || (loading && items.length)" class="mt-6 text-center">
      <button
        type="button"
        :disabled="loading"
        class="px-5 py-2 bg-gray-200 dark:bg-gray-700 hover:bg-gray-300 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-200 text-sm rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        @click="load"
      >
        {{ loading ? 'Laden …' : 'Mehr laden' }}
      </button>
    </div>

    <!-- Error on load-more attempt -->
    <p
      v-if="error && items.length"
      class="mt-3 text-center text-sm text-red-500 dark:text-red-400"
    >
      {{ error }}
    </p>
  </div>
</template>
