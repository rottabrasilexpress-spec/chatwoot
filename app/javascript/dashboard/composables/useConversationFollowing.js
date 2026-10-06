/* global axios */
import { computed, reactive, onMounted, onUnmounted } from 'vue';
import { useStore } from 'vuex';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';

const sessions = new Map();
const changedEvent = 'rotta:following-changed';
const messageEvent = 'rotta:following-message';
export function useConversationFollowing({ panel = false } = {}) {
  const store = useStore();
  const session = computed(() => {
    const key = `${store.getters.getCurrentUser?.id}:${store.getters.getCurrentAccountId}`;
    if (!sessions.has(key))
      sessions.set(
        key,
        reactive({
          items: [],
          flags: {},
          busy: {},
          loaded: false,
          loading: false,
          error: '',
          cursor: null,
          hasMore: false,
          request: null,
          generation: 0,
        })
      );
    return sessions.get(key);
  });
  const url = () =>
    `/api/v1/accounts/${store.getters.getCurrentAccountId}/conversation_followings`;
  const load = async (more = false) => {
    const state = session.value;
    if (state.loading) return state.request;
    state.loading = true;
    state.error = '';
    const params = more ? { before_id: state.cursor } : {};
    const generation = state.generation;
    state.request = axios
      .get(url(), { params, timeout: 10000 })
      .then(({ data }) => {
        if (generation !== state.generation) return;
        data.items = data.items.map(item => {
          const current = state.items.find(old => old.id === item.id);
          return current?.last_message?.id > (item.last_message?.id || 0)
            ? { ...item, last_message: current.last_message }
            : item;
        });
        state.items = more
          ? [
              ...state.items,
              ...data.items.filter(
                item => !state.items.some(old => old.id === item.id)
              ),
            ]
          : data.items;
        data.items.forEach(item => {
          state.flags[item.id] = true;
        });
        state.cursor = data.next_cursor;
        state.hasMore = data.has_more;
        state.loaded = true;
      })
      .catch(() => {
        state.error =
          'Não foi possível atualizar o acompanhamento. Tente novamente.';
      })
      .finally(() => {
        state.loading = false;
        if (generation !== state.generation && panel && state === session.value)
          // eslint-disable-next-line no-use-before-define -- This asynchronous callback runs after refresh is initialized.
          refresh();
      });
    return state.request;
  };
  const status = async id => {
    if (!id) return;
    const state = session.value;
    const generation = state.generation;
    try {
      const { data } = await axios.get(`${url()}/${id}`, { timeout: 10000 });
      if (generation === state.generation) state.flags[id] = data.following;
    } catch {
      state.error =
        'Não foi possível confirmar o acompanhamento deste cliente.';
    }
  };
  const setFollowing = async (id, active) => {
    const state = session.value;
    if (!id || state.busy[id]) return false;
    const account = store.getters.getCurrentAccountId;
    state.busy[id] = true;
    state.error = '';
    try {
      const endpoint = `${url()}/${id}`;
      const { data } = active
        ? await axios.patch(endpoint, {}, { timeout: 10000 })
        : await axios.delete(endpoint, { timeout: 10000 });
      state.generation += 1;
      state.flags[id] = data.following;
      if (!data.following)
        state.items = state.items.filter(item => item.id !== id);
      emitter.emit(changedEvent, {
        account_id: account,
        id,
        following: data.following,
      });
      return true;
    } catch {
      state.error =
        'Não foi possível alterar o acompanhamento. Tente novamente.';
      return false;
    } finally {
      state.busy[id] = false;
    }
  };
  let refreshTimer;
  function refresh() {
    clearTimeout(refreshTimer);
    refreshTimer = setTimeout(() => load(), 500);
  }
  const changed = event => {
    if (Number(event.account_id) !== Number(store.getters.getCurrentAccountId))
      return;
    const state = session.value;
    state.generation += 1;
    state.flags[event.id] = event.following;
    if (!event.following)
      state.items = state.items.filter(item => item.id !== event.id);
    if (panel) refresh();
  };
  const message = event => {
    if (
      Number(event.account_id) !== Number(store.getters.getCurrentAccountId) ||
      event.private ||
      ![0, 1, 'incoming', 'outgoing'].includes(event.message_type)
    )
      return;
    const item = session.value.items.find(
      value => value.id === event.conversation_id
    );
    if (!item || (item.last_message?.id || 0) > event.id) return;
    item.last_message = {
      id: event.id,
      content: event.content,
      message_type: event.message_type,
      content_type: event.attachments?.[0]?.file_type || event.content_type,
      created_at: event.created_at,
    };
  };
  const focused = () => {
    if (panel && document.visibilityState === 'visible') refresh();
  };
  onMounted(() => {
    emitter.on(changedEvent, changed);
    if (panel) {
      emitter.on(messageEvent, message);
      window.addEventListener('focus', focused);
      document.addEventListener('visibilitychange', focused);
      emitter.on(BUS_EVENTS.WEBSOCKET_RECONNECT, focused);
    }
  });
  onUnmounted(() => {
    emitter.off(changedEvent, changed);
    emitter.off(messageEvent, message);
    window.removeEventListener('focus', focused);
    document.removeEventListener('visibilitychange', focused);
    emitter.off(BUS_EVENTS.WEBSOCKET_RECONNECT, focused);
    clearTimeout(refreshTimer);
  });
  return { session, load, status, setFollowing };
}
