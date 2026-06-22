<script setup lang="ts">
import { ref } from 'vue'
import GalleryGrid from '@/components/GalleryGrid.vue'
import MediaViewer from '@/components/MediaViewer.vue'
import type { MediaRead } from '@/api/media'

const viewerItem = ref<MediaRead | null>(null)
const viewerItems = ref<MediaRead[]>([])

function openViewer(item: MediaRead, items: MediaRead[]) {
  viewerItem.value = item
  viewerItems.value = items
}

function closeViewer() {
  viewerItem.value = null
}
</script>

<template>
  <div>
    <h1 class="text-2xl font-bold text-gray-900 dark:text-gray-100 mb-6">
      Galerie
    </h1>
    <GalleryGrid @open="openViewer" />
    <!-- v-if ensures MediaViewer only mounts when open:
         keyboard listener, body scroll lock and blob URL cleanup
         are all tied to onMounted/onUnmounted and never leak. -->
    <MediaViewer
      v-if="viewerItem !== null"
      :item="viewerItem"
      :items="viewerItems"
      @close="closeViewer"
    />
  </div>
</template>
