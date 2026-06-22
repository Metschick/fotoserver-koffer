import { API_BASE, fetchJson } from './client'

export interface MediaRead {
  id: number
  filename: string
  mime_type: string
  size_bytes: number
  device_name: string
  uploaded_at: string
  album_path: string
  thumb_path: string | null
}

export interface GalleryPage {
  items: MediaRead[]
  total: number
  limit: number
  offset: number
}

export interface UploadHandle {
  promise: Promise<MediaRead>
  abort: () => void
}

export function uploadFile(
  file: File,
  deviceName: string,
  onProgress: (pct: number) => void,
): UploadHandle {
  let xhrRef: XMLHttpRequest | null = null

  const promise = new Promise<MediaRead>((resolve, reject) => {
    const form = new FormData()
    form.append('file', file)
    form.append('device_name', deviceName)

    const xhr = new XMLHttpRequest()
    xhrRef = xhr
    xhr.open('POST', `${API_BASE}/upload`)

    xhr.upload.onprogress = (e) => {
      if (e.lengthComputable) {
        onProgress(Math.round((e.loaded / e.total) * 100))
      }
    }

    xhr.onload = () => {
      if (xhr.status === 201) {
        try {
          resolve(JSON.parse(xhr.responseText) as MediaRead)
        } catch {
          reject(new Error('Ungültige Server-Antwort'))
        }
      } else {
        let detail = xhr.statusText
        try {
          const body = JSON.parse(xhr.responseText) as { detail?: string }
          if (body.detail) detail = body.detail
        } catch { /* ignore */ }
        reject(new Error(`Fehler ${xhr.status}: ${detail}`))
      }
    }

    xhr.onerror = () => reject(new Error('Netzwerkfehler beim Upload'))
    xhr.onabort = () => reject(new Error('Upload abgebrochen'))
    xhr.send(form)
  })

  return {
    promise,
    abort: () => xhrRef?.abort(),
  }
}

export function fetchGallery(limit = 50, offset = 0, signal?: AbortSignal): Promise<GalleryPage> {
  return fetchJson<GalleryPage>(
    `/gallery?limit=${limit}&offset=${offset}`,
    signal ? { signal } : undefined,
  )
}

export async function fetchMediaBlob(mediaId: number): Promise<string> {
  const resp = await fetch(`${API_BASE}/media/${mediaId}/file`)
  if (!resp.ok) {
    let detail = resp.statusText
    try {
      const body = await resp.json() as { detail?: string }
      if (body.detail) detail = body.detail
    } catch { /* ignore */ }
    throw new Error(`Fehler ${resp.status}: ${detail}`)
  }
  const blob = await resp.blob()
  return URL.createObjectURL(blob)
}
