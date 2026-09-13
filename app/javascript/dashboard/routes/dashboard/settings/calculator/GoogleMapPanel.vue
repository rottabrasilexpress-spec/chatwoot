<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text, no-bitwise, no-plusplus, no-use-before-define -->
<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import {
  buildGoogleDirectionsUrl,
  buildGooglePlaceUrl,
  decodeGooglePolyline,
  getGoogleMapEndpoints,
} from './googleMapHelpers';

const props = defineProps({
  origin: { type: String, default: '' },
  destination: { type: String, default: '' },
  route: { type: Object, default: null },
});

const mapElement = ref(null);
const map = ref(null);
const routeLine = ref(null);
const originMarker = ref(null);
const destinationMarker = ref(null);
const originOverlay = ref(null);
const destinationOverlay = ref(null);
let resizeObserver;
let resizeFrame;
const mapError = ref('');
const isLoading = ref(true);
const activeMapType = ref('roadmap');
let scriptPromise;

const config = computed(() => window.chatwootConfig || {});
const apiKey = computed(
  () =>
    config.value.rottaGoogleMapsApiKey ||
    config.value.googleMapsApiKey ||
    document.querySelector('meta[name="rotta-google-maps-api-key"]')?.content ||
    ''
);
const hasRoute = computed(() => Boolean(props.route?.route_polyline));
const hasOrigin = computed(() => Boolean(String(props.origin || '').trim()));
const hasDestination = computed(() =>
  Boolean(String(props.destination || '').trim())
);
const hasEndpoints = computed(() => hasOrigin.value && hasDestination.value);
const mapsLink = computed(() =>
  buildGoogleDirectionsUrl(props.origin, props.destination)
);
const originLink = computed(() => buildGooglePlaceUrl(props.origin));
const destinationLink = computed(() => buildGooglePlaceUrl(props.destination));

const loadGoogleMaps = () => {
  if (window.google?.maps?.Map) {
    window.dispatchEvent(new Event('rotta-google-maps-ready'));
    return Promise.resolve(window.google.maps);
  }
  if (!apiKey.value)
    return Promise.reject(new Error('Google Maps não configurado'));
  if (scriptPromise) return scriptPromise;

  scriptPromise = new Promise((resolve, reject) => {
    const callbackName = '__rottaGoogleMapsReady';
    const resolveMaps = () => {
      if (window.google?.maps?.Map) {
        delete window[callbackName];
        window.dispatchEvent(new Event('rotta-google-maps-ready'));
        resolve(window.google.maps);
      }
    };
    window[callbackName] = resolveMaps;

    const existing = document.querySelector('script[data-rotta-google-maps]');
    if (existing) {
      existing.addEventListener('load', resolveMaps);
      existing.addEventListener('error', error => {
        delete window[callbackName];
        reject(error);
      });
      return;
    }

    const script = document.createElement('script');
    script.src = `https://maps.googleapis.com/maps/api/js?key=${encodeURIComponent(
      apiKey.value
    )}&libraries=geometry,places&language=pt-BR&region=BR&loading=async&callback=${callbackName}`;
    script.async = true;
    script.defer = true;
    script.dataset.rottaGoogleMaps = 'true';
    script.onload = resolveMaps;
    script.onerror = () =>
      (() => {
        delete window[callbackName];
        reject(new Error('Não foi possível carregar o Google Maps'));
      })();
    document.head.appendChild(script);
  });

  return scriptPromise;
};

const drawRoute = () => {
  if (!map.value || !window.google?.maps) return;
  if (routeLine.value) routeLine.value.setMap(null);
  if (originMarker.value) originMarker.value.setMap(null);
  if (destinationMarker.value) destinationMarker.value.setMap(null);
  clearEndpointOverlays();
  originMarker.value = null;
  destinationMarker.value = null;

  const points = decodeGooglePolyline(props.route?.route_polyline);
  if (!points.length) return;

  routeLine.value = new window.google.maps.Polyline({
    path: points,
    geodesic: true,
    strokeColor: '#f97316',
    strokeOpacity: 0.95,
    strokeWeight: 5,
    map: map.value,
  });

  const endpoints = getGoogleMapEndpoints(props.route?.route_polyline);
  if (endpoints && window.google.maps.Marker) {
    const markerIcon = fillColor => ({
      path: window.google.maps.SymbolPath.CIRCLE,
      scale: 12,
      fillColor,
      fillOpacity: 1,
      strokeColor: '#ffffff',
      strokeWeight: 3,
    });
    originMarker.value = new window.google.maps.Marker({
      position: endpoints.origin,
      map: map.value,
      icon: markerIcon('#2563eb'),
      label: { text: 'A', color: '#ffffff', fontWeight: '700' },
      title: 'Origem',
    });
    destinationMarker.value = new window.google.maps.Marker({
      position: endpoints.destination,
      map: map.value,
      icon: markerIcon('#e11d48'),
      label: { text: 'B', color: '#ffffff', fontWeight: '700' },
      title: 'Destino',
    });
    originOverlay.value = createEndpointOverlay(
      endpoints.origin,
      'A',
      '#2563eb'
    );
    destinationOverlay.value = createEndpointOverlay(
      endpoints.destination,
      'B',
      '#e11d48'
    );
  }

  const bounds = new window.google.maps.LatLngBounds();
  points.forEach(point => bounds.extend(point));
  map.value.fitBounds(bounds, 48);
};

const refreshMapViewport = () => {
  resizeFrame = undefined;
  if (!map.value || !window.google?.maps || !mapElement.value) return;

  const { width, height } = mapElement.value.getBoundingClientRect();
  if (!width || !height) return;

  window.google.maps.event.trigger(map.value, 'resize');
  if (hasRoute.value) drawRoute();
};

const scheduleMapViewportRefresh = () => {
  if (resizeFrame) cancelAnimationFrame(resizeFrame);
  resizeFrame = requestAnimationFrame(() => {
    resizeFrame = requestAnimationFrame(refreshMapViewport);
  });
};

const setMapType = type => {
  activeMapType.value = type;
  map.value?.setMapTypeId(type);
};

const clearEndpointOverlays = () => {
  originOverlay.value?.setMap(null);
  destinationOverlay.value?.setMap(null);
  originOverlay.value = null;
  destinationOverlay.value = null;
};

const createEndpointOverlay = (position, label, color) => {
  const OverlayView = window.google?.maps?.OverlayView;
  if (!OverlayView) return null;

  const overlay = new OverlayView();
  overlay.onAdd = () => {
    const element = document.createElement('div');
    element.textContent = label;
    Object.assign(element.style, {
      alignItems: 'center',
      background: color,
      border: '3px solid #ffffff',
      borderRadius: '9999px',
      boxShadow: '0 2px 8px rgba(15, 23, 42, 0.35)',
      color: '#ffffff',
      display: 'flex',
      fontFamily: 'Arial, sans-serif',
      fontSize: '13px',
      fontWeight: '700',
      height: '30px',
      justifyContent: 'center',
      pointerEvents: 'none',
      position: 'absolute',
      transform: 'translate(-50%, -50%)',
      width: '30px',
      zIndex: '3',
    });
    overlay.element = element;
    overlay.getPanes()?.floatPane?.appendChild(element);
  };
  overlay.draw = () => {
    const projection = overlay.getProjection();
    if (!projection || !overlay.element) return;
    const point = projection.fromLatLngToDivPixel(
      new window.google.maps.LatLng(position)
    );
    if (!point) return;
    overlay.element.style.left = `${point.x}px`;
    overlay.element.style.top = `${point.y}px`;
  };
  overlay.onRemove = () => {
    overlay.element?.remove();
    overlay.element = null;
  };
  overlay.setMap(map.value);
  return overlay;
};

const focusRoute = () => {
  if (hasRoute.value) drawRoute();
  document
    .querySelector('[data-testid="calculator-google-map"]')
    ?.scrollIntoView({ behavior: 'smooth', block: 'center' });
};

const initializeMap = async () => {
  isLoading.value = true;
  mapError.value = '';
  try {
    const maps = await loadGoogleMaps();
    map.value = new maps.Map(mapElement.value, {
      center: { lat: -14.235, lng: -51.9253 },
      zoom: 4,
      mapTypeControl: false,
      mapTypeId: activeMapType.value,
      streetViewControl: true,
      fullscreenControl: true,
      gestureHandling: 'greedy',
    });
    drawRoute();
    resizeObserver = new ResizeObserver(scheduleMapViewportRefresh);
    resizeObserver.observe(mapElement.value);
    scheduleMapViewportRefresh();
  } catch (error) {
    mapError.value = error.message;
  } finally {
    isLoading.value = false;
  }
};

watch(
  () => props.route?.route_polyline,
  () => {
    drawRoute();
    scheduleMapViewportRefresh();
  }
);
defineExpose({ focusRoute });
onMounted(initializeMap);
onBeforeUnmount(() => {
  resizeObserver?.disconnect();
  if (resizeFrame) cancelAnimationFrame(resizeFrame);
  if (routeLine.value) routeLine.value.setMap(null);
  if (originMarker.value) originMarker.value.setMap(null);
  if (destinationMarker.value) destinationMarker.value.setMap(null);
  clearEndpointOverlays();
  map.value = null;
});
</script>

<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<template>
  <section
    class="flex flex-col overflow-hidden border rounded-2xl border-n-weak bg-n-solid-1"
    data-testid="calculator-google-map"
  >
    <div
      class="flex flex-wrap items-center justify-between gap-3 px-4 py-3 border-b border-n-weak"
    >
      <div class="flex items-center gap-2">
        <Icon icon="i-lucide-map" class="size-4 text-n-brand" />
        <div>
          <p class="text-xs font-bold tracking-wider uppercase text-n-slate-11">
            Mapa e rota
          </p>
          <p class="text-sm font-semibold text-n-slate-12">
            Navegação operacional
          </p>
        </div>
      </div>
      <div class="flex flex-wrap items-center justify-end gap-2">
        <span
          v-if="hasRoute"
          class="px-2 py-1 text-xs font-medium rounded-full bg-n-teal-3 text-n-teal-11"
          >Rota traçada</span
        >
        <span
          v-if="hasRoute"
          class="px-2 py-1 text-xs font-medium rounded-full bg-n-blue-3 text-n-blue-11"
          >{{
            route?.route_provider === 'google-routes'
              ? 'Google Routes'
              : 'Fallback de rota'
          }}</span
        >
        <a
          :href="mapsLink"
          target="_blank"
          rel="noopener noreferrer"
          class="px-2 py-1 text-xs font-medium border rounded-lg border-n-weak text-n-slate-11 hover:text-n-brand"
          >Abrir no Google Maps</a
        >
      </div>
    </div>
    <div
      class="flex flex-wrap items-center gap-2 px-4 py-2 border-b border-n-weak bg-n-alpha-1"
      data-testid="calculator-map-actions"
    >
      <a
        :href="hasOrigin ? originLink : undefined"
        :aria-disabled="!hasOrigin"
        class="inline-flex items-center gap-1.5 px-2.5 py-1.5 text-[11px] font-semibold tracking-wide uppercase border rounded-lg transition-colors"
        :class="[
          hasOrigin
            ? 'border-n-weak text-n-slate-11 hover:border-n-brand hover:text-n-brand'
            : 'cursor-not-allowed border-n-weak text-n-slate-9 opacity-60',
        ]"
        target="_blank"
        rel="noopener noreferrer"
        title="Abrir a localização da origem no Google Maps"
      >
        <Icon icon="i-lucide-camera" class="size-3.5" />
        Foto origem
      </a>
      <a
        :href="hasDestination ? destinationLink : undefined"
        :aria-disabled="!hasDestination"
        class="inline-flex items-center gap-1.5 px-2.5 py-1.5 text-[11px] font-semibold tracking-wide uppercase border rounded-lg transition-colors"
        :class="[
          hasDestination
            ? 'border-n-weak text-n-slate-11 hover:border-n-brand hover:text-n-brand'
            : 'cursor-not-allowed border-n-weak text-n-slate-9 opacity-60',
        ]"
        target="_blank"
        rel="noopener noreferrer"
        title="Abrir a localização do destino no Google Maps"
      >
        <Icon icon="i-lucide-camera" class="size-3.5" />
        Foto destino
      </a>
      <button
        type="button"
        class="inline-flex items-center gap-1.5 px-2.5 py-1.5 text-[11px] font-semibold tracking-wide uppercase border rounded-lg border-n-weak text-n-slate-11 hover:border-n-brand hover:text-n-brand disabled:cursor-not-allowed disabled:opacity-60"
        :disabled="!hasRoute"
        title="Centralizar a rota no mapa"
        @click="focusRoute"
      >
        <Icon icon="i-lucide-route" class="size-3.5" />
        Ver rota
      </button>
      <a
        :href="hasEndpoints ? mapsLink : undefined"
        :aria-disabled="!hasEndpoints"
        class="inline-flex items-center gap-1.5 px-2.5 py-1.5 text-[11px] font-semibold tracking-wide uppercase border rounded-lg transition-colors"
        :class="[
          hasEndpoints
            ? 'border-n-brand/40 bg-n-brand/10 text-n-brand hover:bg-n-brand/20'
            : 'cursor-not-allowed border-n-weak text-n-slate-9 opacity-60',
        ]"
        target="_blank"
        rel="noopener noreferrer"
        title="Abrir a rota no Google Maps para navegação GPS"
      >
        <Icon icon="i-lucide-navigation" class="size-3.5" />
        Abrir GPS
      </a>
    </div>
    <div class="relative min-h-[24rem] bg-n-alpha-2">
      <div
        ref="mapElement"
        class="absolute inset-0"
        data-testid="calculator-google-map-canvas"
      />
      <div
        class="absolute z-10 flex overflow-hidden border rounded-lg shadow-sm left-3 top-3 border-n-weak bg-n-solid-1"
        data-testid="calculator-map-types"
      >
        <button
          v-for="type in [
            { id: 'roadmap', label: 'Mapa' },
            { id: 'satellite', label: 'Satélite' },
            { id: 'terrain', label: 'Relevo' },
          ]"
          :key="type.id"
          type="button"
          class="px-3 py-2 text-xs font-semibold transition-colors"
          :class="
            activeMapType === type.id
              ? 'bg-n-brand text-white'
              : 'text-n-slate-11 hover:bg-n-alpha-2'
          "
          @click="setMapType(type.id)"
        >
          {{ type.label }}
        </button>
      </div>
      <div
        v-if="isLoading"
        class="absolute inset-0 flex items-center justify-center bg-n-solid-1/80"
      >
        <div class="flex items-center gap-2 text-sm text-n-slate-11">
          <Icon icon="i-lucide-loader-circle" class="size-4 animate-spin" />
          Carregando Google Maps…
        </div>
      </div>
      <div
        v-else-if="mapError"
        class="absolute inset-0 flex flex-col items-center justify-center gap-2 p-6 text-center bg-n-solid-1"
      >
        <Icon icon="i-lucide-map-pin-off" class="size-7 text-n-slate-10" />
        <p class="text-sm font-medium text-n-slate-12">
          Mapa visual indisponível neste ambiente
        </p>
        <p class="max-w-sm text-xs text-n-slate-11">
          A rota continua sendo calculada no backend. Configure uma chave Google
          Maps com restrição de domínio para exibir o mapa aqui.
        </p>
        <a
          :href="mapsLink"
          target="_blank"
          rel="noopener noreferrer"
          class="text-xs font-semibold text-n-brand"
          >Abrir rota no Google Maps</a
        >
      </div>
    </div>
    <div class="grid grid-cols-3 gap-2 p-3 text-xs border-t border-n-weak">
      <div>
        <p class="text-n-slate-11">Distância</p>
        <p class="mt-1 font-semibold text-n-slate-12">
          {{ route?.distance_km ? `${route.distance_km} km` : 'Aguardando' }}
        </p>
      </div>
      <div>
        <p class="text-n-slate-11">Tempo estimado</p>
        <p class="mt-1 font-semibold text-n-slate-12">
          {{
            route?.duration_minutes
              ? `${route.duration_minutes} min`
              : 'Aguardando'
          }}
        </p>
      </div>
      <div>
        <p class="text-n-slate-11">Pedágios</p>
        <p class="mt-1 font-semibold text-n-teal-11">Desativados</p>
      </div>
    </div>
  </section>
</template>
