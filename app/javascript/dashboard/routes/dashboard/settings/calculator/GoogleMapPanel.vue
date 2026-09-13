<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text, no-bitwise, no-plusplus -->
<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import {
  buildGoogleDirectionsUrl,
  buildGooglePlaceUrl,
} from './googleMapHelpers';

const props = defineProps({
  origin: { type: String, default: '' },
  destination: { type: String, default: '' },
  route: { type: Object, default: null },
});

const mapElement = ref(null);
const map = ref(null);
const routeLine = ref(null);
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
const hasEndpoints = computed(() => Boolean(props.origin && props.destination));
const mapsLink = computed(() =>
  buildGoogleDirectionsUrl(props.origin, props.destination)
);
const originLink = computed(() => buildGooglePlaceUrl(props.origin));
const destinationLink = computed(() => buildGooglePlaceUrl(props.destination));

const decodePolyline = encoded => {
  if (!encoded) return [];
  const points = [];
  let index = 0;
  let latitude = 0;
  let longitude = 0;

  while (index < encoded.length) {
    let shift = 0;
    let result = 0;
    let byte;
    do {
      byte = encoded.charCodeAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    latitude += result & 1 ? ~(result >> 1) : result >> 1;

    shift = 0;
    result = 0;
    do {
      byte = encoded.charCodeAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    longitude += result & 1 ? ~(result >> 1) : result >> 1;
    points.push({ lat: latitude / 1e5, lng: longitude / 1e5 });
  }

  return points;
};

const loadGoogleMaps = () => {
  if (window.google?.maps?.Map) return Promise.resolve(window.google.maps);
  if (!apiKey.value)
    return Promise.reject(new Error('Google Maps não configurado'));
  if (scriptPromise) return scriptPromise;

  scriptPromise = new Promise((resolve, reject) => {
    const callbackName = '__rottaGoogleMapsReady';
    const resolveMaps = () => {
      if (window.google?.maps?.Map) {
        delete window[callbackName];
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
    )}&libraries=geometry&language=pt-BR&region=BR&loading=async&callback=${callbackName}`;
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
  const points = decodePolyline(props.route?.route_polyline);
  if (!points.length) return;

  routeLine.value = new window.google.maps.Polyline({
    path: points,
    geodesic: true,
    strokeColor: '#f97316',
    strokeOpacity: 0.95,
    strokeWeight: 5,
    map: map.value,
  });

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
        :href="hasEndpoints ? originLink : undefined"
        :aria-disabled="!hasEndpoints"
        class="inline-flex items-center gap-1.5 px-2.5 py-1.5 text-[11px] font-semibold tracking-wide uppercase border rounded-lg transition-colors"
        :class="[
          hasEndpoints
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
        :href="hasEndpoints ? destinationLink : undefined"
        :aria-disabled="!hasEndpoints"
        class="inline-flex items-center gap-1.5 px-2.5 py-1.5 text-[11px] font-semibold tracking-wide uppercase border rounded-lg transition-colors"
        :class="[
          hasEndpoints
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
