<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue'
import { API_BASE } from '@/api/client'
import { type MediaRead, fetchMediaBlob } from '@/api/media'

// This component is always mounted with a non-null item (parent uses v-if="viewerItem")
const props = defineProps<{
  item: MediaRead
  items: MediaRead[]
}>()

const emit = defineEmits<{
  close: []
}>()

const currentItem = ref<MediaRead>(props.item)
const blobUrl = ref<string | null>(null)
const blobLoading = ref(false)
const blobError = ref<string | null>(null)
const closeBtn = ref<HTMLButtonElement>()

// On mount: lock body scroll, focus close button
onMounted(() => {
  document.body.style.overflow = 'hidden'
  closeBtn.value?.focus()
})

// On unmount: unlock body scroll, revoke blob URL, remove keyboard listener
onUnmounted(() => {
  document.body.style.overflow = ''
  if (blobUrl.value) URL.revokeObjectURL(blobUrl.value)
  document.removeEventListener('keydown', onKeydown)
})

// Load full-size image blob when current item changes; skip for videos.
// Stale-ID guard prevents a slow fetch from overwriting a faster one when navigating quickly.
watch(
  currentItem,
  async (item) => {
    if (blobUrl.value) {
      URL.revokeObjectURL(blobUrl.value)
      blobUrl.value = null
    }
    blobError.value = null

    if (!item.mime_type.startsWith('image/')) {
      blobLoading.value = false
      return
    }

    const targetId = item.id
    blobLoading.value = true
    try {
      const url = await fetchMediaBlob(targetId)
      if (currentItem.value.id !== targetId) {
        URL.revokeObjectURL(url)
        return
      }
      blobUrl.value = url
    } catch (err) {
      if (currentItem.value.id !== targetId) return
      blobError.value = err instanceof Error ? err.message : 'Bild konnte nicht geladen werden'
    } finally {
      if (currentItem.value.id === targetId) blobLoading.value = false
    }
  },
  { immediate: true },
)

// Navigation
const currentIndex = computed(() => {
  const id = currentItem.value.id
  return props.items.findIndex((i) => i.id === id)
})

const hasPrev = computed(() => currentIndex.value > 0)
const hasNext = computed(() => currentIndex.value < props.items.length - 1)

const prevItem = computed(() =>
  hasPrev.value ? props.items[currentIndex.value - 1] : null,
)
const nextItem = computed(() =>
  hasNext.value ? props.items[currentIndex.value + 1] : null,
)

function goPrev() {
  if (hasPrev.value) currentItem.value = props.items[currentIndex.value - 1]
}

function goNext() {
  if (hasNext.value) currentItem.value = props.items[currentIndex.value + 1]
}

function close() {
  emit('close')
}

function onBackdropClick(e: MouseEvent) {
  if (e.target === e.currentTarget) close()
}

function onKeydown(e: KeyboardEvent) {
  if (e.key === 'Escape') close()
  if (e.key === 'ArrowLeft') goPrev()
  if (e.key === 'ArrowRight') goNext()
}

onMounted(() => document.addEventListener('keydown', onKeydown))

function formatDate(iso: string): string {
  return new Date(iso).toLocaleString('de-DE', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

function formatBytes(bytes: number): string {
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`
}
</script>

<template>
  <Teleport to="body">
    <Transition name="viewer-fade">
      <div
        role="dialog"
        aria-modal="true"
        :aria-label="currentItem.filename"
        aria-describedby="viewer-meta"
        class="fixed inset-0 z-50 flex flex-col bg-black/90 select-none"
        @click="onBackdropClick"
      >
        <!-- Header -->
        <div class="flex items-center justify-between gap-3 px-4 py-3 shrink-0">
          <div class="min-w-0">
            <p class="text-sm font-medium text-white truncate">{{ currentItem.filename }}</p>
            <p id="viewer-meta" class="text-xs text-white/60 truncate">
              {{ currentItem.device_name }} &middot; {{ formatDate(currentItem.uploaded_at) }}
              &middot; {{ formatBytes(currentItem.size_bytes) }}
            </p>
          </div>
          <div class="flex items-center gap-2 shrink-0">
            <!-- Download -->
            <a
              :href="`${API_BASE}/media/${currentItem.id}/file`"
              :aria-label="`${currentItem.filename} herunterladen`"
              class="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-white/10 hover:bg-white/20 text-white text-sm transition-colors"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 20 20"
                fill="currentColor"
                class="w-4 h-4"
              >
                <path
                  d="M10.75 2.75a.75.75 0 00-1.5 0v8.614L6.295 8.235a.75.75 0 10-1.09 1.03l4.25 4.5a.75.75 0 001.09 0l4.25-4.5a.75.75 0 00-1.09-1.03l-2.955 3.129V2.75z"
                />
                <path
                  d="M3.5 12.75a.75.75 0 00-1.5 0v2.5A2.75 2.75 0 004.75 18h10.5A2.75 2.75 0 0018 15.25v-2.5a.75.75 0 00-1.5 0v2.5c0 .69-.56 1.25-1.25 1.25H4.75c-.69 0-1.25-.56-1.25-1.25v-2.5z"
                />
              </svg>
              Herunterladen
            </a>
            <!-- Close -->
            <button
              ref="closeBtn"
              type="button"
              aria-label="Viewer schließen"
              class="p-2 rounded-lg bg-white/10 hover:bg-white/20 text-white transition-colors"
              @click="close"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 20 20"
                fill="currentColor"
                class="w-5 h-5"
              >
                <path
                  d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z"
                />
              </svg>
            </button>
          </div>
        </div>

        <!-- Content area with navigation arrows -->
        <div class="relative flex-1 flex items-center justify-center min-h-0 px-12">
          <!-- Prev arrow -->
          <button
            v-if="hasPrev"
            type="button"
            :aria-label="prevItem?.mime_type.startsWith('video/') ? 'Vorheriges Video' : 'Vorheriges Bild'"
            class="absolute left-2 z-10 p-2 rounded-full bg-white/10 hover:bg-white/20 text-white transition-colors"
            @click.stop="goPrev"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 20 20"
              fill="currentColor"
              class="w-6 h-6"
            >
              <path
                fill-rule="evenodd"
                d="M12.79 5.23a.75.75 0 01-.02 1.06L8.832 10l3.938 3.71a.75.75 0 11-1.04 1.08l-4.5-4.25a.75.75 0 010-1.08l4.5-4.25a.75.75 0 011.06.02z"
                clip-rule="evenodd"
              />
            </svg>
          </button>

          <!-- Image viewer -->
          <div
            v-if="currentItem.mime_type.startsWith('image/')"
            class="flex items-center justify-center max-w-full max-h-full"
          >
            <div v-if="blobLoading" class="text-white/60 text-sm">Bild wird geladen …</div>
            <p v-else-if="blobError" class="text-red-400 text-sm text-center">{{ blobError }}</p>
            <img
              v-else-if="blobUrl"
              :src="blobUrl"
              :alt="currentItem.filename"
              class="max-w-full max-h-full object-contain rounded-sm"
            />
          </div>

          <!-- Video: thumbnail + download hint -->
          <div v-else class="text-center space-y-4">
            <img
              v-if="currentItem.thumb_path"
              :src="`${API_BASE}/media/${currentItem.id}/thumb`"
              :alt="currentItem.filename"
              class="max-w-xs mx-auto rounded-lg"
            />
            <svg
              v-else
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              fill="currentColor"
              class="w-16 h-16 mx-auto text-white/30"
            >
              <path
                fill-rule="evenodd"
                d="M4.5 5.653c0-1.426 1.529-2.33 2.779-1.643l11.54 6.348c1.295.712 1.295 2.573 0 3.285L7.28 19.991c-1.25.687-2.779-.217-2.779-1.643V5.653z"
                clip-rule="evenodd"
              />
            </svg>
            <p class="text-white/60 text-sm">Inline-Wiedergabe nicht verfügbar.</p>
            <a
              :href="`${API_BASE}/media/${currentItem.id}/file`"
              class="inline-flex items-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-medium rounded-lg transition-colors"
            >
              Video herunterladen
            </a>
          </div>

          <!-- Next arrow -->
          <button
            v-if="hasNext"
            type="button"
            :aria-label="nextItem?.mime_type.startsWith('video/') ? 'Nächstes Video' : 'Nächstes Bild'"
            class="absolute right-2 z-10 p-2 rounded-full bg-white/10 hover:bg-white/20 text-white transition-colors"
            @click.stop="goNext"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 20 20"
              fill="currentColor"
              class="w-6 h-6"
            >
              <path
                fill-rule="evenodd"
                d="M7.21 14.77a.75.75 0 01.02-1.06L11.168 10 7.23 6.29a.75.75 0 111.04-1.08l4.5 4.25a.75.75 0 010 1.08l-4.5 4.25a.75.75 0 01-1.06-.02z"
                clip-rule="evenodd"
              />
            </svg>
          </button>
        </div>

        <!-- Counter -->
        <div
          v-if="props.items.length > 1"
          class="py-3 text-center text-white/50 text-xs shrink-0"
        >
          {{ currentIndex + 1 }} / {{ props.items.length }}
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.viewer-fade-enter-active,
.viewer-fade-leave-active {
  transition: opacity 0.15s ease;
}
.viewer-fade-enter-from,
.viewer-fade-leave-to {
  opacity: 0;
}
</style>
