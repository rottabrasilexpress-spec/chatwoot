<script setup>
import { useAttrs } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';

const attrs = useAttrs();
const globalConfig = useMapGetter('globalConfig/get');
const ROTTA_MARK_URL = '/brand-assets/rottabrasil-mark-transparent.png';
</script>

<template>
  <img
    v-if="globalConfig.logoThumbnail"
    v-bind="attrs"
    :src="globalConfig.logoThumbnail"
  />
  <img
    v-else
    v-bind="attrs"
    :src="ROTTA_MARK_URL"
    alt=""
    aria-hidden="true"
    decoding="async"
  />
</template>
