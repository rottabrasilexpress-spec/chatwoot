<script setup>
import { computed, watch } from 'vue';
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
</script>

<template>
  <section
    v-if="!compact || point || session.error"
    :aria-label="copy.title"
    :class="
      compact
        ? 'px-3 py-2 border-b border-n-weak'
        : 'w-full max-w-3xl mx-auto p-4 sm:p-6'
    "
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
      <div class="flex flex-wrap gap-3 justify-between items-center mb-3">
        <h1 class="text-xl font-semibold text-n-slate-12">{{ copy.title }}</h1>
        <button
          type="button"
          class="px-3 py-2 rounded-lg text-sm text-n-brand hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand disabled:opacity-50"
          :disabled="session.loading || session.busy || session.saving"
          @click="retry"
        >
          {{ copy.refresh }}
        </button>
      </div>
      <p class="text-sm text-n-slate-11 mb-6">{{ copy.description }}</p>
      <p v-if="session.loading" role="status" class="text-n-slate-11">
        {{ copy.loading }}
      </p>
      <p v-else-if="!views.length" class="text-n-slate-11">{{ copy.empty }}</p>
      <template
        v-for="section in [
          { title: copy.tabs, points: views },
          { title: copy.history, points: session.history },
        ]"
        :key="section.title"
      >
        <h2
          v-if="section.points.length"
          class="text-base font-semibold mt-6 mb-2 text-n-slate-12"
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
                {{ item.title }}
              </p>
              <p class="text-sm text-n-slate-11 break-words">
                {{ copy.stopped }} {{ item.name }}
              </p>
              <p class="text-sm text-n-brand break-words">
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
