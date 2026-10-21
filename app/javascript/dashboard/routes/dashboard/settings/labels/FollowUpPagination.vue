<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  pagination: { type: Object, required: true },
  loading: { type: Boolean, default: false },
  label: { type: String, required: true },
});
const emit = defineEmits(['page']);
const { t } = useI18n();
const start = computed(() =>
  props.pagination.total
    ? (props.pagination.page - 1) * props.pagination.per_page + 1
    : 0
);
const end = computed(() =>
  Math.min(
    props.pagination.page * props.pagination.per_page,
    props.pagination.total
  )
);
</script>

<template>
  <nav
    :aria-label="label"
    class="flex flex-wrap items-center justify-between gap-3 border-y border-n-weak py-3 my-3"
  >
    <span
      class="text-sm text-n-slate-11 tabular-nums"
      role="status"
      aria-live="polite"
    >
      {{
        t('REPORT.PAGINATION.RESULTS', { start, end, total: pagination.total })
      }}
    </span>
    <div class="flex items-center gap-2">
      <Button
        :label="t('YEAR_IN_REVIEW.NAVIGATION.PREVIOUS')"
        icon="i-lucide-chevron-left"
        size="sm"
        slate
        ghost
        :disabled="loading || pagination.page <= 1"
        @click="emit('page', pagination.page - 1)"
      />
      <span class="text-sm text-n-slate-12 tabular-nums"
        >{{ pagination.page }} / {{ pagination.total_pages }}</span
      >
      <Button
        :label="t('YEAR_IN_REVIEW.NAVIGATION.NEXT')"
        icon="i-lucide-chevron-right"
        size="sm"
        slate
        ghost
        :disabled="loading || pagination.page >= pagination.total_pages"
        @click="emit('page', pagination.page + 1)"
      />
    </div>
  </nav>
</template>
