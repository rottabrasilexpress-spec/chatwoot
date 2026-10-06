<script setup>
import { computed, watch, onMounted, onUnmounted } from 'vue';
import { useConversationReview } from 'dashboard/composables/useConversationReview';
const props = defineProps({
  view: { type: String, default: '' },
  compact: { type: Boolean, default: false },
});
const { session, load, flush, resume } = useConversationReview();
const point = computed(() => session.value.views[props.view]);
const views = computed(() =>
  Object.values(session.value.views).sort((a, b) =>
    (b.updated_at || '').localeCompare(a.updated_at || '')
  )
);
const copy = {
  title: 'Retomar revisão',
  description:
    'Seus pontos são salvos automaticamente e só aparecem para você.',
  loading: 'Carregando seus pontos…',
  empty:
    'Abra uma conversa para começar. Seu próximo contato será guardado aqui.',
  tabs: 'Pontos por aba',
  history: 'Últimos cinco pontos',
  stopped: 'Você parou em',
  next: 'Próximo:',
  continue: 'Continuar revisão',
  finished: 'Fim da sequência carregada',
  retry: 'Tentar novamente',
  refresh: 'Atualizar pontos',
  saving: 'Salvando seu ponto…',
  busy: 'Abrindo…',
};
const retry = async () => {
  await flush();
  await load(true);
};
watch(session, () => load(), { immediate: true });
const refreshed = () => {
  if (!props.compact && document.visibilityState === 'visible') retry();
};
onMounted(() => {
  if (!props.compact) {
    retry();
    window.addEventListener('focus', refreshed);
    document.addEventListener('visibilitychange', refreshed);
  }
});
onUnmounted(() => {
  window.removeEventListener('focus', refreshed);
  document.removeEventListener('visibilitychange', refreshed);
});
const titleFor = item =>
  ({
    '#kelvin': 'Orçamentos',
    '#caio-atencao': 'Caio Atenção',
    '#clientes-fechados': 'Clientes Fechados',
    '#finalizados': 'Finalizados',
    '#emitir-contrato': 'Emitir Contrato',
  })[item.title] || item.title;
</script>

<template>
  <section
    v-if="!compact || point || session.error"
    :aria-label="copy.title"
    :class="compact ? 'px-3 py-2 border-b border-n-weak' : 'w-full'"
  >
    <template v-if="compact">
      <button
        v-if="point?.remaining?.length"
        type="button"
        class="flex items-center gap-2 w-full min-w-0 text-sm text-n-brand rounded-lg px-2 py-2 hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand disabled:opacity-50"
        :disabled="session.busy"
        @click="resume(point)"
      >
        <span
          class="i-lucide-bookmark-check size-4 shrink-0"
          aria-hidden="true"
        />
        <span class="truncate text-left">{{
          session.busy ? copy.busy : `${copy.next} ${point.remaining[0].name}`
        }}</span>
        <span
          class="i-lucide-arrow-right size-4 shrink-0 ml-auto"
          aria-hidden="true"
        />
      </button>
      <p v-if="session.saving" role="status" class="text-xs text-n-slate-11">
        {{ copy.saving }}
      </p>
    </template>
    <template v-else>
      <div
        class="flex flex-wrap gap-3 justify-between items-center px-5 py-4 bg-n-brand/10 border-b border-n-brand/20"
      >
        <h1 class="flex items-center gap-2 text-lg font-semibold text-n-brand">
          <span class="i-lucide-bookmark-check size-5" aria-hidden="true" />{{
            copy.title
          }}
        </h1>
        <button
          type="button"
          class="px-3 py-2 rounded-lg text-sm text-n-brand hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand disabled:opacity-50"
          :disabled="session.loading || session.busy || session.saving"
          @click="retry"
        >
          {{ copy.refresh }}
        </button>
        <p class="w-full text-sm text-n-slate-11">{{ copy.description }}</p>
      </div>
      <div class="px-5 py-4">
        <p v-if="session.loading" role="status" class="text-sm text-n-slate-11">
          {{ copy.loading }}
        </p>
        <p v-else-if="!views.length" class="text-n-slate-11">
          {{ copy.empty }}
        </p>
        <template
          v-for="section in [
            { title: copy.tabs, points: views },
            { title: copy.history, points: session.history },
          ]"
          :key="section.title"
        >
          <h2
            v-if="section.points.length"
            class="flex items-center gap-2 text-sm font-semibold mt-5 first:mt-0 mb-2 text-n-slate-12"
          >
            {{ section.title }}
          </h2>
          <ul class="m-0 list-none divide-y divide-n-weak">
            <li
              v-for="item in section.points"
              :key="item.id"
              class="py-4 flex flex-wrap gap-3 items-center justify-between"
            >
              <div class="min-w-0 flex-1 basis-44">
                <p class="font-semibold text-n-slate-12 break-words">
                  {{ titleFor(item) }}
                </p>
                <p class="text-sm text-n-slate-11 break-words">
                  {{ copy.stopped }} {{ item.name }}
                </p>
                <p class="mt-1 text-sm text-n-brand break-words">
                  {{
                    item.remaining.length
                      ? `${copy.next} ${item.remaining[0].name}`
                      : copy.finished
                  }}
                </p>
              </div>
              <button
                type="button"
                class="px-3 py-2 rounded-lg bg-n-brand text-white text-sm font-medium hover:opacity-90 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand disabled:opacity-50"
                :disabled="!item.remaining.length || session.busy"
                @click="resume(item)"
              >
                {{ session.busy ? copy.busy : copy.continue }}
              </button>
            </li>
          </ul>
        </template>
      </div>
    </template>
    <div
      v-if="session.error"
      role="alert"
      class="mt-2 text-sm text-n-ruby-11 break-words"
    >
      {{ session.error }}
      <button
        type="button"
        class="underline ml-2 py-2"
        :disabled="session.loading || session.saving"
        @click="retry"
      >
        {{ copy.retry }}
      </button>
    </div>
    <p v-if="session.notice" role="status" class="mt-2 text-sm text-n-slate-11">
      {{ session.notice }}
    </p>
  </section>
</template>
