<script setup lang="ts">
import { computed, onUnmounted, ref, watch } from 'vue'
import { type MediaRead, uploadFile } from '@/api/media'

interface UploadItem {
  id: string
  file: File
  preview: string | null
  status: 'pending' | 'uploading' | 'done' | 'error'
  progress: number
  result: MediaRead | null
  error: string | null
}

const DEVICE_NAME_RE = /^[a-zA-Z0-9_-]{1,50}$/
const MAX_BYTES = 10240 * 1024 * 1024
const ALLOWED_TYPES = new Set([
  'image/jpeg',
  'image/png',
  'image/gif',
  'image/webp',
  'video/mp4',
  'video/quicktime',
])
const DEVICE_NAME_KEY = 'fotoserver-device-name'

// crypto.randomUUID() erfordert einen Secure Context (HTTPS/localhost) und ist
// auf dem Hotspot (reines HTTP auf 192.168.4.1) nicht verfügbar — die Exception
// verhinderte bisher lautlos jedes Hinzufügen einer Datei zur Upload-Liste.
// crypto.getRandomValues() ist dagegen in jedem Context verfügbar.
function generateItemId(): string {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID()
  }
  if (typeof crypto !== 'undefined' && crypto.getRandomValues) {
    const bytes = crypto.getRandomValues(new Uint8Array(16))
    bytes[6] = (bytes[6] & 0x0f) | 0x40
    bytes[8] = (bytes[8] & 0x3f) | 0x80
    const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('')
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`
  }
  return `${Date.now().toString(16)}-${Math.random().toString(16).slice(2)}`
}

const deviceName = ref(localStorage.getItem(DEVICE_NAME_KEY) ?? '')
const items = ref<UploadItem[]>([])
const rejectedMessages = ref<string[]>([])
const isDragging = ref(false)
const uploading = ref(false)
const fileInput = ref<HTMLInputElement>()

// Tracks the abort function for the currently in-flight XHR (plain variable, not reactive)
let currentAbort: (() => void) | null = null

const deviceNameValid = computed(() => DEVICE_NAME_RE.test(deviceName.value))
const pendingCount = computed(() => items.value.filter((i) => i.status === 'pending').length)
const canUpload = computed(
  () => deviceNameValid.value && pendingCount.value > 0 && !uploading.value,
)

watch(deviceName, (val) => {
  if (DEVICE_NAME_RE.test(val)) {
    localStorage.setItem(DEVICE_NAME_KEY, val)
  }
})

onUnmounted(() => {
  currentAbort?.()
  for (const item of items.value) {
    if (item.preview) URL.revokeObjectURL(item.preview)
  }
})

function addFiles(newFiles: File[]) {
  rejectedMessages.value = []
  for (const f of newFiles) {
    if (!ALLOWED_TYPES.has(f.type)) {
      rejectedMessages.value.push(`„${f.name}": Dateityp nicht unterstützt`)
      continue
    }
    if (f.size > MAX_BYTES) {
      rejectedMessages.value.push(`„${f.name}": Datei zu groß (max. 10 GB)`)
      continue
    }
    items.value.push({
      id: generateItemId(),
      file: f,
      preview: f.type.startsWith('image/') ? URL.createObjectURL(f) : null,
      status: 'pending',
      progress: 0,
      result: null,
      error: null,
    })
  }
}

function removeItem(id: string) {
  const idx = items.value.findIndex((i) => i.id === id)
  if (idx === -1) return
  const item = items.value[idx]
  if (item.preview) URL.revokeObjectURL(item.preview)
  items.value.splice(idx, 1)
}

function clearDone() {
  for (const item of items.value.filter((i) => i.status === 'done')) {
    if (item.preview) URL.revokeObjectURL(item.preview)
  }
  items.value = items.value.filter((i) => i.status !== 'done')
}

function onDragover(e: DragEvent) {
  e.preventDefault()
  isDragging.value = true
}

function onDragleave(e: DragEvent) {
  const related = e.relatedTarget
  if (related instanceof Node && (e.currentTarget as HTMLElement).contains(related)) return
  isDragging.value = false
}

function onDrop(e: DragEvent) {
  e.preventDefault()
  isDragging.value = false
  addFiles(Array.from(e.dataTransfer?.files ?? []))
}

function openFilePicker() {
  fileInput.value?.click()
}

function onFileInput(e: Event) {
  const input = e.target as HTMLInputElement
  addFiles(Array.from(input.files ?? []))
  input.value = ''
}

async function startUpload() {
  if (!canUpload.value) return
  uploading.value = true

  // Snapshot so files added via drag-drop mid-upload don't enter this batch
  const batch = [...items.value]

  for (const item of batch) {
    if (item.status !== 'pending') continue

    item.status = 'uploading'
    item.progress = 0
    item.error = null

    const { promise, abort } = uploadFile(item.file, deviceName.value, (pct) => {
      item.progress = pct
    })
    currentAbort = abort

    try {
      item.result = await promise
      item.status = 'done'
      item.progress = 100
    } catch (err) {
      item.status = 'error'
      item.error = err instanceof Error ? err.message : 'Unbekannter Fehler'
    } finally {
      currentAbort = null
    }
  }

  uploading.value = false
}

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`
  return `${(bytes / 1024 / 1024 / 1024).toFixed(2)} GB`
}
</script>

<template>
  <div class="space-y-6">
    <!-- Gerätename -->
    <div>
      <label
        for="device-name"
        class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1"
      >
        Gerätename
      </label>
      <input
        id="device-name"
        v-model="deviceName"
        type="text"
        maxlength="50"
        placeholder="z. B. iPhone-Anna"
        :class="[
          'w-full px-3 py-2 rounded-lg border text-sm transition-colors',
          'bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100',
          'focus:outline-none focus:ring-2 focus:border-transparent',
          deviceName && !deviceNameValid
            ? 'border-red-400 dark:border-red-500 focus:ring-red-500'
            : 'border-gray-300 dark:border-gray-600 focus:ring-blue-500',
        ]"
      />
      <p v-if="deviceName && !deviceNameValid" class="mt-1 text-xs text-red-500">
        Nur Buchstaben, Ziffern, <code>-</code> und <code>_</code> erlaubt (1–50 Zeichen).
      </p>
      <p v-else class="mt-1 text-xs text-gray-500 dark:text-gray-400">
        Buchstaben, Ziffern, <code>-</code> und <code>_</code> erlaubt.
      </p>
    </div>

    <!-- Drop-Zone -->
    <div
      role="button"
      tabindex="0"
      aria-label="Dateien für den Upload auswählen oder hier ablegen"
      :class="[
        'relative border-2 border-dashed rounded-xl p-8 text-center transition-colors cursor-pointer',
        isDragging
          ? 'border-blue-500 bg-blue-50 dark:bg-blue-900/20'
          : 'border-gray-300 dark:border-gray-600 hover:border-blue-400 dark:hover:border-blue-500',
      ]"
      @dragover="onDragover"
      @dragleave="onDragleave"
      @drop="onDrop"
      @click="openFilePicker"
      @keydown.enter.prevent="openFilePicker"
      @keydown.space.prevent="openFilePicker"
    >
      <input
        ref="fileInput"
        type="file"
        multiple
        tabindex="-1"
        accept="image/jpeg,image/png,image/gif,image/webp,video/mp4,video/quicktime"
        class="sr-only"
        @change="onFileInput"
      />

      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="currentColor"
        class="w-10 h-10 mx-auto mb-3 text-gray-400 dark:text-gray-500"
      >
        <path
          fill-rule="evenodd"
          d="M11.47 2.47a.75.75 0 011.06 0l4.5 4.5a.75.75 0 01-1.06 1.06l-3.22-3.22V16.5a.75.75 0 01-1.5 0V4.81L8.03 8.03a.75.75 0 01-1.06-1.06l4.5-4.5zM3 15.75a.75.75 0 01.75.75v2.25a1.5 1.5 0 001.5 1.5h13.5a1.5 1.5 0 001.5-1.5V16.5a.75.75 0 011.5 0v2.25a3 3 0 01-3 3H5.25a3 3 0 01-3-3V16.5a.75.75 0 01.75-.75z"
          clip-rule="evenodd"
        />
      </svg>

      <p class="text-sm font-medium text-gray-700 dark:text-gray-300">
        Dateien hier ablegen oder
        <span class="text-blue-600 dark:text-blue-400">auswählen</span>
      </p>
      <p class="mt-1 text-xs text-gray-500 dark:text-gray-400">
        JPEG, PNG, GIF, WebP, MP4, MOV &middot; max. 10 GB pro Datei
      </p>
    </div>

    <!-- Abgelehnte Dateien -->
    <div
      v-if="rejectedMessages.length"
      class="rounded-lg border border-amber-300 dark:border-amber-600 bg-amber-50 dark:bg-amber-900/20 px-4 py-3"
    >
      <p class="text-xs font-medium text-amber-700 dark:text-amber-400 mb-1">
        Folgende Dateien wurden nicht hinzugefügt:
      </p>
      <ul class="space-y-0.5">
        <li
          v-for="(msg, idx) in rejectedMessages"
          :key="idx"
          class="text-xs text-amber-700 dark:text-amber-400"
        >
          {{ msg }}
        </li>
      </ul>
    </div>

    <!-- Dateiliste -->
    <ul v-if="items.length" class="space-y-2">
      <li
        v-for="item in items"
        :key="item.id"
        class="flex items-start gap-3 p-3 rounded-lg bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700"
      >
        <!-- Vorschau -->
        <div
          class="w-12 h-12 shrink-0 rounded-md overflow-hidden bg-gray-200 dark:bg-gray-700 flex items-center justify-center"
        >
          <img
            v-if="item.preview"
            :src="item.preview"
            :alt="item.file.name"
            class="w-full h-full object-cover"
          />
          <svg
            v-else
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="currentColor"
            class="w-6 h-6 text-gray-400"
          >
            <path
              fill-rule="evenodd"
              d="M4.5 5.653c0-1.426 1.529-2.33 2.779-1.643l11.54 6.348c1.295.712 1.295 2.573 0 3.285L7.28 19.991c-1.25.687-2.779-.217-2.779-1.643V5.653z"
              clip-rule="evenodd"
            />
          </svg>
        </div>

        <!-- Info + Fortschritt -->
        <div class="flex-1 min-w-0">
          <p class="text-sm font-medium text-gray-800 dark:text-gray-200 truncate">
            {{ item.file.name }}
          </p>
          <p class="text-xs text-gray-500 dark:text-gray-400">{{ formatBytes(item.file.size) }}</p>

          <div
            v-if="item.status === 'uploading' || item.status === 'done'"
            class="mt-1.5"
          >
            <div class="h-1.5 bg-gray-200 dark:bg-gray-600 rounded-full overflow-hidden">
              <div
                class="h-full bg-blue-500 rounded-full transition-all duration-300"
                :style="{ width: `${item.progress}%` }"
              />
            </div>
          </div>

          <p v-if="item.status === 'error'" class="mt-1 text-xs text-red-500">
            {{ item.error }}
          </p>
          <p
            v-else-if="item.status === 'done'"
            class="mt-1 text-xs text-green-600 dark:text-green-400"
          >
            Hochgeladen &#10003;
          </p>
        </div>

        <!-- Status-Icon + Entfernen -->
        <div class="shrink-0 flex items-center gap-1">
          <svg
            v-if="item.status === 'uploading'"
            class="w-5 h-5 animate-spin text-blue-500"
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
          >
            <circle
              class="opacity-25"
              cx="12"
              cy="12"
              r="10"
              stroke="currentColor"
              stroke-width="4"
            />
            <path
              class="opacity-75"
              fill="currentColor"
              d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
            />
          </svg>
          <svg
            v-else-if="item.status === 'done'"
            class="w-5 h-5 text-green-500"
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="currentColor"
          >
            <path
              fill-rule="evenodd"
              d="M2.25 12c0-5.385 4.365-9.75 9.75-9.75s9.75 4.365 9.75 9.75-4.365 9.75-9.75 9.75S2.25 17.385 2.25 12zm13.36-1.814a.75.75 0 10-1.22-.872l-3.236 4.53L9.53 12.22a.75.75 0 00-1.06 1.06l2.25 2.25a.75.75 0 001.14-.094l3.75-5.25z"
              clip-rule="evenodd"
            />
          </svg>
          <svg
            v-else-if="item.status === 'error'"
            class="w-5 h-5 text-red-500"
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="currentColor"
          >
            <path
              fill-rule="evenodd"
              d="M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25zm-1.72 6.97a.75.75 0 10-1.06 1.06L10.94 12l-1.72 1.72a.75.75 0 101.06 1.06L12 13.06l1.72 1.72a.75.75 0 101.06-1.06L13.06 12l1.72-1.72a.75.75 0 10-1.06-1.06L12 10.94l-1.72-1.72z"
              clip-rule="evenodd"
            />
          </svg>

          <button
            v-if="item.status !== 'uploading'"
            type="button"
            :aria-label="`${item.file.name} entfernen`"
            class="p-1 rounded text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 transition-colors"
            @click.stop="removeItem(item.id)"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 20 20"
              fill="currentColor"
              class="w-4 h-4"
            >
              <path
                d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z"
              />
            </svg>
          </button>
        </div>
      </li>
    </ul>

    <!-- Aktionsleiste -->
    <div v-if="items.length" class="flex items-center justify-between gap-3">
      <button
        v-if="items.some((i) => i.status === 'done')"
        type="button"
        class="text-sm text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200 transition-colors"
        @click="clearDone"
      >
        Erledigte entfernen
      </button>
      <span v-else />

      <button
        type="button"
        :disabled="!canUpload"
        :class="[
          'px-5 py-2 rounded-lg text-sm font-medium transition-colors',
          canUpload
            ? 'bg-blue-600 hover:bg-blue-700 text-white'
            : 'bg-gray-200 dark:bg-gray-700 text-gray-400 dark:text-gray-500 cursor-not-allowed',
        ]"
        @click="startUpload"
      >
        {{
          uploading
            ? 'Wird hochgeladen …'
            : `${pendingCount} Datei${pendingCount !== 1 ? 'en' : ''} hochladen`
        }}
      </button>
    </div>
  </div>
</template>
