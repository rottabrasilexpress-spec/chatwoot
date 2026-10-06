<script setup>
import { watch, computed, ref } from 'vue';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import { useConversationFollowing } from 'dashboard/composables/useConversationFollowing';
import {
  followingMessagePreview,
  reviewWorkspacePath,
} from 'dashboard/helper/reviewWorkspace';
import ConversationApi from 'dashboard/api/inbox/conversation';
import Avatar from 'next/avatar/Avatar.vue';
import { useAlert } from 'dashboard/composables';
const store = useStore();
const copy = {
  title: 'Acompanhar clientes',
  refresh: 'Atualizar clientes',
  retry: 'Tentar novamente',
  description:
    'Lista compartilhada com a equipe. Não altera etiquetas ou a IA.',
  loading: 'Carregando clientes…',
  emptyTitle: 'Quem você quer acompanhar?',
  empty:
    'Abra uma conversa e clique em “Acompanhar cliente”. Ela aparecerá aqui para toda a equipe.',
  opening: 'Abrindo conversa…',
  ours: 'Nossa resposta',
  client: 'Cliente',
  more: 'Mostrar mais clientes',
  loadingMore: 'Carregando…',
};
const router = useRouter();
const { session, load, setFollowing } = useConversationFollowing({
  panel: true,
});
const opening = ref(null);
const accountId = computed(() => store.getters.getCurrentAccountId);
watch(session, () => load(), { immediate: true });
const open = async item => {
  if (opening.value) return;
  const state = session.value;
  const account = accountId.value;
  opening.value = item.id;
  try {
    const { data } = await ConversationApi.show(item.id);
    if (session.value !== state) return;
    await router.push(reviewWorkspacePath(data, account));
  } catch {
    useAlert(
      'Não foi possível abrir esta conversa. Atualize a lista e tente novamente.'
    );
  } finally {
    opening.value = null;
  }
};
const remove = async item => {
  if (await setFollowing(item.id, false))
    useAlert('Cliente retirado do acompanhamento da equipe.');
  else useAlert(session.value.error);
};
const time = message =>
  message?.created_at
    ? new Date(message.created_at * 1000).toLocaleString('pt-BR', {
        day: '2-digit',
        month: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
      })
    : '';
</script>

<template>
  <section :aria-label="copy.title" class="min-w-0">
    <header
      class="flex flex-wrap items-center justify-between gap-3 border-b border-n-teal-4 bg-n-teal-2 px-5 py-4"
    >
      <h2 class="flex items-center gap-2 text-lg font-semibold text-n-teal-11">
        <span class="i-lucide-eye size-5" aria-hidden="true" />{{ copy.title }}
      </h2>
      <button
        type="button"
        class="rounded-lg px-3 py-2 text-sm text-n-teal-11 hover:bg-n-teal-3 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand disabled:opacity-50"
        :disabled="session.loading"
        @click="load()"
      >
        {{ copy.refresh }}
      </button>
      <p class="w-full text-sm text-n-teal-11">
        {{ copy.description }}
      </p>
    </header>
    <div class="px-5 py-4">
      <p v-if="session.error" role="alert" class="mb-3 text-sm text-n-ruby-11">
        {{ session.error }}
        <button type="button" class="underline py-2" @click="load()">
          {{ copy.retry }}
        </button>
      </p>
      <p
        v-if="session.loading && !session.items.length"
        role="status"
        class="text-sm text-n-slate-11"
      >
        {{ copy.loading }}
      </p>
      <div
        v-else-if="!session.items.length"
        class="py-8 text-center text-n-slate-11"
      >
        <span
          class="i-lucide-messages-square mx-auto block size-8 mb-3"
          aria-hidden="true"
        />
        <p class="font-medium text-n-slate-12">{{ copy.emptyTitle }}</p>
        <p class="mt-2 text-sm">
          {{ copy.empty }}
        </p>
      </div>
      <ul class="list-none m-0 p-0 divide-y divide-n-weak">
        <li
          v-for="item in session.items"
          :key="item.id"
          class="flex items-start gap-2 py-3"
        >
          <button
            type="button"
            :disabled="Boolean(opening)"
            class="flex flex-1 min-w-0 gap-3 rounded-lg p-2 text-left hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand disabled:opacity-60"
            @click="open(item)"
          >
            <Avatar
              :name="item.name"
              :src="item.avatar_url"
              :size="36"
              rounded-full
            />
            <span class="min-w-0 flex-1">
              <span class="flex flex-wrap gap-2 items-center justify-between"
                ><span
                  class="break-words font-semibold text-sm text-n-slate-12"
                  >{{ item.name }}</span
                ><time class="text-xs text-n-slate-11">{{
                  time(item.last_message)
                }}</time></span
              >
              <span class="mt-1 flex items-start gap-1 text-xs text-n-teal-11"
                ><span
                  class="i-lucide-message-circle size-3.5 shrink-0 mt-0.5"
                  aria-hidden="true"
                />{{
                  [1, 'outgoing'].includes(item.last_message?.message_type)
                    ? copy.ours
                    : copy.client
                }}</span
              >
              <span
                class="mt-1 block text-sm text-n-slate-11 break-words line-clamp-3 whitespace-pre-line"
                >{{ followingMessagePreview(item.last_message) }}</span
              >
              <span v-if="opening === item.id" class="text-xs text-n-brand">{{
                copy.opening
              }}</span>
            </span>
          </button>
          <button
            type="button"
            :aria-label="`Retirar ${item.name} do acompanhamento`"
            :disabled="session.busy[item.id]"
            class="rounded-lg p-2 text-n-slate-11 hover:bg-n-ruby-2 hover:text-n-ruby-11 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand disabled:opacity-50"
            @click="remove(item)"
          >
            <span class="i-lucide-x size-4" aria-hidden="true" />
          </button>
        </li>
      </ul>
      <button
        v-if="session.hasMore"
        type="button"
        :disabled="session.loading"
        class="mt-4 w-full rounded-lg border border-n-weak px-3 py-2 text-sm text-n-brand hover:bg-n-alpha-2 disabled:opacity-50"
        @click="load(true)"
      >
        {{ session.loading ? copy.loadingMore : copy.more }}
      </button>
    </div>
  </section>
</template>
