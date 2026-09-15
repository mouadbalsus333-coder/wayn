import { useEffect, useRef } from 'react'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
type Props = {
  latitude: number
  longitude: number
}

const PIN_ZOOM = 16

/**
 * Read-only map preview for a contribution's coordinates (Admin).
 *
 * Uses the same Leaflet + OpenStreetMap tiles already used by
 * LocationMapPicker — no new map library. Centers automatically on the
 * contribution coordinates and drops a fixed pin.
 */
export function ContributionPreviewMap({ latitude, longitude }: Props) {
  const containerRef = useRef<HTMLDivElement | null>(null)

  useEffect(() => {
    const container = containerRef.current
    if (!container) return

    const map = L.map(container, {
      center: [latitude, longitude],
      zoom: PIN_ZOOM,
      scrollWheelZoom: false,
    })

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
      maxZoom: 19,
    }).addTo(map)

    L.circleMarker([latitude, longitude], {
      radius: 9,
      color: '#2563eb',
      fillColor: '#2563eb',
      fillOpacity: 0.85,
      weight: 2,
    })
      .addTo(map)
      .bindTooltip(`${latitude.toFixed(6)}, ${longitude.toFixed(6)}`)

    // Ensure the tile grid renders after the modal lays out.
    setTimeout(() => map.invalidateSize(), 50)

    return () => {
      map.remove()
    }
  }, [latitude, longitude])

  return (
    <div
      ref={containerRef}
      dir="ltr"
      className="place-map contribution-preview-map"
    />
  )
}
