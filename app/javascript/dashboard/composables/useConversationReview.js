/* global axios */
/* eslint-disable no-await-in-loop, no-continue -- Sequential reads/writes deliberately avoid request bursts and preserve click order. */
import { reactive, computed } from 'vue';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import ConversationApi from '../api/inbox/conversation';
import {
  reviewWorkspacePath,
  reviewWorkspaceDestination,
} from '../helper/reviewWorkspace';
import {
  createReviewPoint,
  reviewConversationEligible,
  reviewViewKey,
} from '../helper/conversationReview';

// One shared request queue, regardless of how many list/sidebar components mount.
const sessions = new Map();
export function useConversationReview() {
  const store = useStore();
  const router = useRouter();
  const accountId = computed(() => store.getters.getCurrentAccountId);
  const userId = computed(() => store.getters.getCurrentUser?.id);
  const session = computed(() => {
    const key = `${userId.value}:${accountId.value}`;
    if (!sessions.has(key))
      sessions.set(
        key,
        reactive({
          views: {},
          history: [],
          loaded: false,
          loading: false,
          error: '',
          notice: '',
          busy: false,
          pending: [],
          saving: false,
          timer: null,
          loadPromise: null,
          generation: 0,
        })
      );
    return sessions.get(key);
  });
  const url = () => `/api/v1/accounts/${accountId.value}/review_points`;
  const load = async (force = false) => {
    const state = session.value;
    if (state.loading) return state.loadPromise;
    if (state.loaded && !force) return undefined;
    state.loading = true;
    state.error = '';
    const generation = state.generation;
    state.loadPromise = (async () => {
      try {
        const { data } = await axios.get(url(), { timeout: 10000 });
        // Do not overwrite unsaved clicks with an earlier GET response.
        if (
          generation === state.generation &&
          !state.pending.length &&
          !state.saving
        )
          Object.assign(state, data);
        state.loaded = true;
      } catch {
        state.error = 'Não foi possível carregar seus pontos. Tente novamente.';
      } finally {
        state.loading = false;
      }
    })();
    return state.loadPromise;
  };
  const flush = async (state = session.value, endpoint = url()) => {
    if (state.saving) return;
    state.saving = true;
    clearTimeout(state.timer);
    try {
      while (state.pending.length) {
        const points = state.pending.slice(0, 5);
        const { data } = await axios.patch(
          endpoint,
          { points },
          { timeout: 10000 }
        );
        state.pending.splice(0, points.length);
        if (!state.pending.length) Object.assign(state, data);
      }
      state.error = '';
    } catch {
      state.error =
        'Seu ponto ainda não foi salvo. Tente novamente antes de sair.';
    } finally {
      state.saving = false;
    }
  };
  const save = (point, state = session.value, endpoint = url()) => {
    state.generation += 1;
    state.views = { ...state.views, [point.view]: point };
    state.history = [
      point,
      ...state.history.filter(item => item.id !== point.id),
    ].slice(0, 5);
    state.pending.push(point);
    state.notice = '';
    clearTimeout(state.timer);
    state.timer = setTimeout(() => flush(state, endpoint), 200);
  };
  const record = (list, conversation, context, title) =>
    save(createReviewPoint(list, conversation, context, title));
  const resume = async point => {
    const state = session.value;
    if (state.busy) return;
    state.busy = true;
    state.error = '';
    state.notice = '';
    const resumeAccountId = accountId.value;
    const resumeUserId = userId.value;
    const endpoint = url();
    try {
      for (let index = 0; index < point.remaining.length; index += 1) {
        const candidate = point.remaining[index];
        if (session.value !== state) return;
        let conversation;
        try {
          ({ data: conversation } = await ConversationApi.show(candidate.id));
        } catch (error) {
          if ([403, 404].includes(error.response?.status)) continue;
          throw error;
        }
        if (session.value !== state) return;
        if (
          ['mention', 'participating'].includes(point.context.conversationType)
        ) {
          const { data } = await axios.get(endpoint, {
            params: {
              candidate_id: candidate.id,
              conversation_type: point.context.conversationType,
            },
            timeout: 10000,
          });
          if (session.value !== state) return;
          if (!data.eligible) continue;
        }
        if (
          !reviewConversationEligible(conversation, point.context, resumeUserId)
        )
          continue;
        await router.push({
          path: reviewWorkspacePath(conversation, resumeAccountId),
          query: { review: point.id, review_open: 'workspace' },
        });
        if (session.value !== state) return;
        const destination = reviewWorkspaceDestination(conversation);
        const context = {
          ...point.context,
          label: destination.label || '',
          conversationType: destination.conversationType || '',
          inboxId: 0,
          teamId: 0,
          foldersId: 0,
          status: 'all',
          assigneeType: 'all',
          filters: [],
        };
        const titles = {
          finalizados: 'Finalizados',
          'clientes-fechados': 'Clientes Fechados',
          'emitir-contrato': 'Emitir Contrato',
          'caio-atencao': 'Caio Atenção',
        };
        save(
          {
            ...point,
            context,
            view: reviewViewKey(context),
            title:
              destination.conversationType === 'archived'
                ? 'Arquivados'
                : titles[destination.label] || 'Todos',
            conversation_id: candidate.id,
            name: conversation.meta?.sender?.name || candidate.name,
            remaining: point.remaining.slice(index + 1),
          },
          state,
          endpoint
        );
        return;
      }
      if (session.value !== state) return;
      save({ ...point, remaining: [] }, state, endpoint);
      state.notice =
        'Você chegou ao fim desta sequência. Clique em um contato da lista para iniciar outra.';
    } catch {
      state.error =
        'Não foi possível abrir a próxima conversa. Tente novamente.';
    } finally {
      state.busy = false;
    }
  };
  return { session, load, flush, record, resume };
}
