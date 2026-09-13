<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text, no-bitwise, no-plusplus -->
<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  origin: { type: String, default: '' },
  destination: { type: String, default: '' },
  route: { type: Object, default: null },
});

const mapElement = ref(null);
const map = ref(null);
const routeLine = ref(null);
const mapError = ref('');
const isLoading = ref(true);
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
const mapsLink = computed(() => {
  const points = [props.origin, props.destination].filter(Boolean);
  return points.length === 2
    ? `https://www.google.com/maps/dir/${encodeURIComponent(points[0])}/${encodeURIComponent(points[1])}`
    : 'https://maps.google.com';
});

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
  if (window.google?.maps) return Promise.resolve(window.google.maps);
  if (!apiKey.value)
    return Promise.reject(new Error('Google Maps não configurado'));
  if (scriptPromise) return scriptPromise;

  scriptPromise = new Promise((resolve, reject) => {
    const existing = document.querySelector('script[data-rotta-google-maps]');
    if (existing) {
      existing.addEventListener('load', () => resolve(window.google.maps));
      existing.addEventListener('error', reject);
      return;
    }

    const script = document.createElement('script');
    script.src = `https://maps.googleapis.com/maps/api/js?key=${encodeURIComponent(
      apiKey.value
    )}&libraries=geometry&language=pt-BR&region=BR&loading=async`;
    script.async = true;
    script.defer = true;
    script.dataset.rottaGoogleMaps = 'true';
    script.onload = () => resolve(window.google.maps);
    script.onerror = () =>
      reject(new Error('Não foi possível carregar o Google Maps'));
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

const initializeMap = async () => {
  isLoading.value = true;
  mapError.value = '';
  try {
    const maps = await loadGoogleMaps();
    map.value = new maps.Map(mapElement.value, {
      center: { lat: -14.235, lng: -51.9253 },
      zoom: 4,
      mapTypeControl: true,
      streetViewControl: true,
      fullscreenControl: true,
      gestureHandling: 'greedy',
    });
    drawRoute();
  } catch (error) {
    mapError.value = error.message;
  } finally {
    isLoading.value = false;
  }
};

watch(() => props.route?.route_polyline, drawRoute);
onMounted(initializeMap);
onBeforeUnmount(() => {
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
      <div class="flex flex-wrap gap-2">
        <span
          v-if="hasRoute"
          class="px-2 py-1 text-xs font-medium rounded-full bg-n-teal-3 text-n-teal-11"
          >Rota traçada</span
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
    <div class="relative min-h-[24rem] bg-n-alpha-2">
      <div
        ref="mapElement"
        class="absolute inset-0"
        data-testid="calculator-google-map-canvas"
      />
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
