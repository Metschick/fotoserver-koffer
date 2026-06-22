export const API_BASE = '/api'

export class ApiError extends Error {
  constructor(
    public readonly status: number,
    message: string,
  ) {
    super(message)
    this.name = 'ApiError'
  }
}

export async function fetchJson<T>(path: string, init?: RequestInit): Promise<T> {
  const resp = await fetch(`${API_BASE}${path}`, init)
  if (!resp.ok) {
    const detail = await resp.text().catch(() => resp.statusText)
    throw new ApiError(resp.status, `API-Fehler ${resp.status}: ${detail}`)
  }
  return resp.json() as Promise<T>
}
