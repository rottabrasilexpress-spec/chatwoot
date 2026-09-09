<script setup>
import { computed, useAttrs } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';

const attrs = useAttrs();
const globalConfig = useMapGetter('globalConfig/get');
const ROTTA_MARK_URL = '/brand-assets/rottabrasil-mark-transparent.png';
const configuredLogo = computed(() => globalConfig.value?.logoThumbnail || '');
const hasCustomConfiguredLogo = computed(
  () =>
    Boolean(configuredLogo.value) &&
    !String(configuredLogo.value).includes('/logo_thumbnail.svg')
);
</script>

<template>
  <img v-if="hasCustomConfiguredLogo" v-bind="attrs" :src="configuredLogo" />
  <img
    v-else
    v-bind="attrs"
    :src="ROTTA_MARK_URL"
    alt=""
    aria-hidden="true"
    decoding="async"
  />
</template>
