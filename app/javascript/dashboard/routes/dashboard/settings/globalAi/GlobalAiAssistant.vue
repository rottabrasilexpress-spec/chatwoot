<!-- eslint-disable -->
<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import globalAiAPI from 'dashboard/api/globalAi';
import {
  canRemoveFollowUpLabel,
  followUpActionLabel,
  isExecutableFollowUpJob,
  removeFollowUpJob,
  requiresFollowUpHours,
} from './globalAiFollowUp';

const router = useRouter();
const { accountId } = useAccount();
const currentUser = useMapGetter('getCurrentUser');

const question = ref('');
const messages = ref([]);
const threadId = ref(null);
const resultCards = ref([]);
const isLoading = ref(false);
const isLoadingAccess = ref(true);
const access = ref({
  allowed: false,
  owner: false,
  agents: [],
  shared_user_ids: [],
});
const selectedAgents = ref([]);
const isSharing = ref(false);
const expandedEvidence = ref(null);
const followUpActionLoading = ref(null);

const stateKey = computed(
  () =>
    `rotta-global-ai:${accountId.value || 'default'}:${currentUser.value?.id || 'user'}`
);

const restoreState = () => {
  try {
    const saved = JSON.parse(sessionStorage.getItem(stateKey.value) || 'null');
    if (!saved) return;
    threadId.value = saved.threadId || null;
    messages.value = saved.messages || [];
    resultCards.value = saved.resultCards || [];
  } catch {
    sessionStorage.removeItem(stateKey.value);
  }
};

const persistState = () => {
  sessionStorage.setItem(
    stateKey.value,
    JSON.stringify({
      threadId: threadId.value,
      messages: messages.value.slice(-30),
      resultCards: resultCards.value.slice(0, 40),
    })
  );
};

const loadAccess = async () => {
  isLoadingAccess.value = true;
  try {
    const response = await globalAiAPI.getAccess();
    access.value = response.data;
    selectedAgents.value = [...(response.data.shared_user_ids || [])];
    restoreState();
  } catch (error) {
    useAlert(
      error.response?.data?.error ||
        'O assistente global não está disponível para este agente.'
    );
  } finally {
    isLoadingAccess.value = false;
  }
};

const sendQuestion = async () => {
  const text = question.value.trim();
  if (!text || isLoading.value) return;

  messages.value.push({ role: 'user', content: text });
  question.value = '';
  isLoading.value = true;
  try {
    const response = threadId.value
      ? await globalAiAPI.createMessage(threadId.value, text)
      : await globalAiAPI.createThread(text);
    const payload = response.data;
    threadId.value = payload.thread?.id || threadId.value;
    const answer = payload.response || {};
    messages.value.push({
      role: 'assistant',
      content: answer.answer || 'Não foi possível obter uma resposta.',
    });
    resultCards.value = answer.cards || [];
    persistState();
  } catch (error) {
    messages.value.push({
      role: 'assistant',
      content:
        error.response?.data?.error || 'Não foi possível responder agora.',
    });
  } finally {
    isLoading.value = false;
  }
};

const openConversation = card => {
  persistState();
  router.push(card.open_url);
};

const executeStatusAction = async card => {
  const confirmed = window.confirm(
    `Marcar a conversa de ${card.customer_name || 'este cliente'} como resolvida? Isso remove a conversa das pendências abertas.`
  );
  if (!confirmed) return;

  try {
    await globalAiAPI.executeAction({
      action: 'set_status',
      conversation_id: card.conversation_id,
      status: 'resolved',
      confirmed: true,
    });
    card.status = 'resolved';
    resultCards.value = resultCards.value.filter(item => item !== card);
    persistState();
    useAlert('Conversa marcada como resolvida.');
  } catch (error) {
    useAlert(
      error.response?.data?.error || 'Não foi possível alterar o status.'
    );
  }
};

const executeFollowUpAction = async (card, job, operation) => {
  const executable = isExecutableFollowUpJob(job);
  const removable = operation === 'remove_label' && canRemoveFollowUpLabel(job);
  if ((!executable && !removable) || followUpActionLoading.value) return;

  let hours;
  if (requiresFollowUpHours(operation)) {
    const input = window.prompt(
      `${followUpActionLabel(operation)} o follow-up em quantas horas?`,
      '24'
    );
    if (input === null) return;
    hours = Number(input);
    if (!Number.isFinite(hours) || hours <= 0 || hours > 24 * 365) {
      useAlert('Informe um prazo entre 1 e 8760 horas.');
      return;
    }
  }

  const target = card.customer_name || `conversa #${card.conversation_id}`;
  const hoursText = hours ? ` para ${hours} horas` : '';
  const confirmed = window.confirm(
    `${followUpActionLabel(operation)} o follow-up de ${target}${hoursText}? Essa ação será aplicada no painel de Follow-up.`
  );
  if (!confirmed) return;

  const actionKey = `${card.conversation_id}:${job.job_id}:${operation}`;
  followUpActionLoading.value = actionKey;
  try {
    const response = await globalAiAPI.executeAction({
      action: `follow_up_${operation}`,
      conversation_id: card.conversation_id,
      job_id: job.job_id,
      ...(operation === 'remove_label'
        ? { label: job.current_label || job.source_label }
        : {}),
      ...(hours ? { hours } : {}),
      confirmed: true,
    });
    const result = response.data?.result || {};
    if (
      operation === 'cancel' ||
      operation === 'dispatch_now' ||
      operation === 'remove_label'
    ) {
      card.follow_up_jobs = removeFollowUpJob(card.follow_up_jobs, job.job_id);
    } else {
      Object.assign(job, result);
    }
    persistState();
    useAlert(
      `Follow-up: ${followUpActionLabel(operation).toLowerCase()} concluído.`
    );
  } catch (error) {
    useAlert(
      error.response?.data?.error ||
        `Não foi possível ${followUpActionLabel(operation).toLowerCase()} o follow-up.`
    );
  } finally {
    followUpActionLoading.value = null;
  }
};

const saveSharing = async () => {
  if (!access.value.owner || isSharing.value) return;
  isSharing.value = true;
  try {
    const response = await globalAiAPI.updateAccess(selectedAgents.value);
    access.value = {
      ...access.value,
      ...response.data,
      shared_user_ids: selectedAgents.value,
    };
    useAlert('Acesso compartilhado atualizado.');
  } catch (error) {
    useAlert(
      error.response?.data?.error ||
        'Não foi possível atualizar o compartilhamento.'
    );
  } finally {
    isSharing.value = false;
  }
};

const hasContent = computed(
  () => messages.value.length > 0 || resultCards.value.length > 0
);

onMounted(loadAccess);
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template -->
  <section
    v-if="!isLoadingAccess && access.allowed"
    class="flex flex-col w-full min-h-[calc(100vh-7rem)] gap-5 pb-8"
  >
    <header class="flex flex-wrap items-start justify-between gap-4 px-1">
      <div class="max-w-3xl">
        <h1 class="text-2xl font-semibold tracking-tight text-n-slate-12">
          Pergunte para IA
        </h1>
        <p class="mt-1 text-sm leading-6 text-n-slate-11">
          Assistente global da operação: cruza conversas, etiquetas, follow-up,
          status e relatórios da conta atual.
        </p>
      </div>
      <div v-if="access.owner" class="relative">
        <details class="group">
          <summary
            class="flex items-center gap-2 px-3 py-2 text-sm font-medium rounded-lg cursor-pointer text-n-slate-12 bg-n-alpha-2 hover:bg-n-alpha-3"
          >
            <span class="i-lucide-users-round size-4" />
            Espelhar para agentes
            <span class="i-lucide-chevron-down size-4" />
          </summary>
          <div
            class="absolute right-0 z-20 w-80 p-4 mt-2 border rounded-xl shadow-lg bg-n-surface-1 border-n-weak"
          >
            <p class="mb-3 text-xs leading-5 text-n-slate-11">
              Escolha quais agentes verão o assistente global no sidebar.
            </p>
            <label
              v-for="agent in access.agents"
              :key="agent.id"
              class="flex items-center gap-2 py-2 text-sm text-n-slate-12"
            >
              <input
                v-model="selectedAgents"
                type="checkbox"
                :value="agent.id"
              />
              <span
                >{{ agent.name }}
                <span class="text-xs text-n-slate-10">{{
                  agent.email
                }}</span></span
              >
            </label>
            <Button
              class="w-full mt-3"
              size="sm"
              color="blue"
              :is-loading="isSharing"
              @click="saveSharing"
            >
              Salvar compartilhamento
            </Button>
          </div>
        </details>
      </div>
    </header>

    <div
      class="grid flex-1 min-h-0 grid-cols-1 gap-5 xl:grid-cols-[minmax(0,1.12fr)_minmax(24rem,0.88fr)]"
    >
      <section
        class="flex flex-col min-h-[38rem] overflow-hidden border rounded-2xl border-n-weak bg-n-surface-1"
      >
        <div
          class="flex items-center justify-between px-5 py-4 border-b border-n-weak"
        >
          <div>
            <h2 class="font-medium text-n-slate-12">
              Conversa com o assistente
            </h2>
            <p class="mt-0.5 text-xs text-n-slate-10">
              Somente agentes autenticados visualizam este painel.
            </p>
          </div>
          <span
            class="inline-flex items-center gap-1.5 px-2 py-1 text-xs rounded-full text-n-slate-11 bg-n-alpha-2"
          >
            <span class="size-1.5 rounded-full bg-n-green-9" />
            Global
          </span>
        </div>
        <div class="flex-1 px-5 py-5 overflow-y-auto">
          <div
            v-if="!hasContent"
            class="flex flex-col items-center justify-center h-full min-h-[24rem] text-center"
          >
            <div
              class="grid mb-4 rounded-2xl size-14 place-items-center bg-n-blue-2 text-n-blue-11"
            >
              <span class="i-lucide-sparkles size-7" />
            </div>
            <h3 class="text-lg font-medium text-n-slate-12">
              O que você quer investigar?
            </h3>
            <p class="max-w-md mt-2 text-sm leading-6 text-n-slate-11">
              Pergunte por pendências, clientes, etiquetas, histórico, números
              ou próximos follow-ups.
            </p>
          </div>
          <div v-else class="flex flex-col gap-4">
            <div
              v-for="(message, index) in messages"
              :key="`${index}-${message.role}`"
              :class="
                message.role === 'user'
                  ? 'self-end max-w-[82%] bg-n-blue-2 text-n-slate-12'
                  : 'self-start max-w-[92%] bg-n-alpha-2 text-n-slate-12'
              "
              class="px-4 py-3 text-sm leading-6 rounded-2xl"
            >
              {{ message.content }}
            </div>
            <div
              v-if="isLoading"
              class="flex items-center gap-2 self-start px-4 py-3 text-sm rounded-2xl text-n-slate-11 bg-n-alpha-2"
            >
              <span class="i-lucide-loader-circle size-4 animate-spin" />
              Consultando a operação…
            </div>
          </div>
        </div>
        <form class="p-4 border-t border-n-weak" @submit.prevent="sendQuestion">
          <TextArea
            v-model="question"
            rows="3"
            placeholder="Ex.: quem está aguardando o financeiro e qual foi a última evidência?"
          />
          <div class="flex items-center justify-between mt-3">
            <span class="text-xs text-n-slate-10"
              >A resposta usa contexto da conta atual e evidencia suas
              fontes.</span
            >
            <Button
              type="submit"
              color="blue"
              :is-loading="isLoading"
              :disabled="!question.trim()"
            >
              <span class="i-lucide-send size-4" />
              Perguntar
            </Button>
          </div>
        </form>
      </section>

      <section
        class="flex flex-col min-h-[38rem] overflow-hidden border rounded-2xl border-n-weak bg-n-surface-1"
      >
        <div
          class="flex items-center justify-between px-5 py-4 border-b border-n-weak"
        >
          <div>
            <h2 class="font-medium text-n-slate-12">
              Resultados selecionáveis
            </h2>
            <p class="mt-0.5 text-xs text-n-slate-10">
              Cada cartão aponta para a conversa e sua evidência.
            </p>
          </div>
          <span class="text-xs text-n-slate-10"
            >{{ resultCards.length }} encontrados</span
          >
        </div>
        <div class="flex-1 p-4 overflow-y-auto">
          <div
            v-if="!resultCards.length"
            class="grid h-full min-h-[24rem] place-items-center text-center text-sm text-n-slate-10"
          >
            Os cartões aparecerão aqui depois da pergunta.
          </div>
          <div v-else class="flex flex-col gap-3">
            <article
              v-for="card in resultCards"
              :key="card.conversation_id"
              class="p-4 border rounded-xl border-n-weak bg-n-background"
            >
              <div class="flex items-start justify-between gap-3">
                <div class="min-w-0">
                  <h3 class="font-medium truncate text-n-slate-12">
                    {{ card.customer_name }}
                  </h3>
                  <p class="mt-1 text-xs text-n-slate-10">
                    #{{ card.conversation_id }} ·
                    {{ card.phone || card.email || 'sem contato cadastrado' }}
                  </p>
                </div>
                <span
                  class="px-2 py-1 text-xs rounded-full text-n-slate-11 bg-n-alpha-2"
                  >{{ card.status }}</span
                >
              </div>
              <div class="flex flex-wrap gap-1.5 mt-3">
                <span
                  v-for="label in card.labels"
                  :key="label"
                  class="px-2 py-1 text-xs rounded-md text-n-slate-11 bg-n-alpha-2"
                  >{{ label }}</span
                >
              </div>
              <p
                v-if="card.evidence"
                class="mt-3 text-xs leading-5 text-n-slate-11"
              >
                <strong class="font-medium text-n-slate-12">Evidência:</strong>
                {{ card.evidence.content }}
              </p>
              <p
                v-if="expandedEvidence === card.conversation_id"
                class="mt-2 text-xs text-n-slate-10"
              >
                {{ card.evidence?.reason }} · {{ card.evidence?.created_at }}
              </p>
              <div
                v-if="card.follow_up_jobs?.length"
                class="p-3 mt-4 border rounded-lg border-n-weak bg-n-alpha-1"
              >
                <div
                  class="flex items-center gap-2 text-xs font-medium text-n-slate-12"
                >
                  <span class="i-lucide-clock-3 size-4 text-n-blue-11" />
                  Follow-up vinculado
                </div>
                <div
                  v-for="job in card.follow_up_jobs"
                  :key="job.job_id"
                  class="pt-3 mt-3 border-t border-n-weak first:pt-2 first:mt-2 first:border-t-0"
                >
                  <div
                    class="flex flex-wrap items-center justify-between gap-2"
                  >
                    <span class="text-xs text-n-slate-11">
                      {{ job.current_label || job.source_label || 'Follow-up' }}
                      <span v-if="job.scheduled_at">
                        · {{ job.scheduled_at }}</span
                      >
                    </span>
                    <span class="text-xs text-n-slate-10">{{
                      job.status || 'ativo'
                    }}</span>
                  </div>
                  <div
                    v-if="
                      isExecutableFollowUpJob(job) ||
                      canRemoveFollowUpLabel(job)
                    "
                    class="flex flex-wrap gap-1.5 mt-2"
                  >
                    <template
                      v-for="operation in [
                        'dispatch_now',
                        'advance',
                        'delay',
                        'cancel',
                        'remove_label',
                      ]"
                      :key="operation"
                    >
                      <Button
                        v-if="
                          operation === 'remove_label'
                            ? canRemoveFollowUpLabel(job)
                            : isExecutableFollowUpJob(job)
                        "
                        size="xs"
                        color="slate"
                        :disabled="Boolean(followUpActionLoading)"
                        :is-loading="
                          followUpActionLoading ===
                          `${card.conversation_id}:${job.job_id}:${operation}`
                        "
                        @click="executeFollowUpAction(card, job, operation)"
                      >
                        {{ followUpActionLabel(operation) }}
                      </Button>
                    </template>
                  </div>
                  <p v-else class="mt-2 text-xs text-n-slate-10">
                    Aguardando sincronização do job remoto.
                  </p>
                </div>
              </div>
              <div class="flex flex-wrap gap-2 mt-4">
                <Button size="sm" color="blue" @click="openConversation(card)">
                  Abrir conversa
                </Button>
                <Button
                  size="sm"
                  color="slate"
                  @click="
                    expandedEvidence =
                      expandedEvidence === card.conversation_id
                        ? null
                        : card.conversation_id
                  "
                >
                  Ver evidência
                </Button>
                <Button
                  v-if="card.status !== 'resolved'"
                  size="sm"
                  color="slate"
                  @click="executeStatusAction(card)"
                >
                  Marcar resolvida
                </Button>
              </div>
            </article>
          </div>
        </div>
      </section>
    </div>
  </section>
  <section
    v-else-if="!isLoadingAccess"
    class="flex flex-col items-center justify-center w-full min-h-[calc(100vh-7rem)] px-6 text-center"
  >
    <span class="mb-4 i-lucide-lock-keyhole size-8 text-n-slate-9" />
    <h1 class="text-xl font-semibold text-n-slate-12">
      Pergunte para IA global indisponível
    </h1>
    <p class="max-w-lg mt-2 text-sm leading-6 text-n-slate-11">
      Esta área interna é liberada somente para Kelvin ou para agentes que ele
      compartilhar explicitamente.
    </p>
  </section>
</template>
