import { useEffect, useRef } from 'react'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'

type Props = {
  latitude?: number | null
  longitude?: number | null
  onSelect: (latitude: number, longitude: number) => void
}

const DEFAULT_CENTER: [number, number] = [32.8872, 13.1913]
const DEFAULT_ZOOM = 12
const SELECTED_ZOOM = 16

/**
 * Lightweight location picker built on Leaflet for the Admin Web Add-Place
 * flow. The admin taps the map to place a pin or drags an existing pin; both
 * actions report the chosen coordinates via `onSelect`. Uses OpenStreetMap
 * tiles — the same open map tiles the WAyN mobile app (MapLibre) relies on.
 */
export function LocationMapPicker({ latitude, longitude, onSelect }: Props) {
  const containerRef = useRef<HTMLDivElement | null>(null)
  const mapRef = useRef<L.Map | null>(null)
  const markerRef = useRef<L.Marker | null>(null)
  const onSelectRef = useRef(onSelect)
  onSelectRef.current = onSelect

  useEffect(() => {
    const container = containerRef.current
    if (!container || mapRef.current) return

    const hasInitial =
      latitude != null && longitude != null
    const center: [number, number] = hasInitial
      ? [latitude as number, longitude as number]
      : DEFAULT_CENTER

    const map = L.map(container, {
      center,
      zoom: hasInitial ? SELECTED_ZOOM : DEFAULT_ZOOM,
      scrollWheelZoom: false,
    })

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
      maxZoom: 19,
    }).addTo(map)

    mapRef.current = map

    const placeMarker = (lat: number, lng: number) => {
      if (markerRef.current) {
        markerRef.current.remove()
        markerRef.current = null
      }
      const marker = L.marker([lat, lng], { draggable: true }).addTo(map)
      marker.on('dragend', () => {
        const point = marker.getLatLng()
        onSelectRef.current(point.lat, point.lng)
      })
      markerRef.current = marker
    }

    map.on('click', (event: L.LeafletMouseEvent) => {
      const { lat, lng } = event.latlng
      placeMarker(lat, lng)
      onSelectRef.current(lat, lng)
    })

    if (hasInitial) {
      placeMarker(center[0], center[1])
    }

    return () => {
      map.remove()
      mapRef.current = null
      markerRef.current = null
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  return <div ref={containerRef} dir="ltr" className="place-map" />
}