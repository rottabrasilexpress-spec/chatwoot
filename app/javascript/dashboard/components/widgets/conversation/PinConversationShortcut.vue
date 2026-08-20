<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, ref } from 'vue';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';

const store = useStore();
const isSaving = ref(false);
const currentChat = computed(() => store.getters.getSelectedChat || {});
const conversationId = computed(() => currentChat.value.id);
const isPinned = computed(() => {
  const value = currentChat.value.custom_attributes?.rotta_pinned;
  return value === true || value === 1 || value === 'true' || value === '1';
});

const togglePin = async () => {
  if (!conversationId.value || isSaving.value) return;

  isSaving.value = true;
  try {
    await store.dispatch('updateCustomAttributes', {
      conversationId: conversationId.value,
      customAttributes: { rotta_pinned: !isPinned.value },
    });
    useAlert(isPinned.value ? 'Conversa fixada.' : 'Conversa desafixada.');
  } catch (error) {
    useAlert(
      'Não foi possível atualizar a fixação da conversa. Tente novamente.'
    );
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <Button
    v-tooltip="isPinned ? 'Desafixar conversa' : 'Fixar conversa'"
    size="sm"
    variant="ghost"
    color="slate"
    :icon="isPinned ? 'i-lucide-pin-off' : 'i-lucide-pin'"
    :label="isPinned ? 'Desafixar' : 'Fixar'"
    class="rotta-pin-shortcut rounded-md"
    :class="{ 'rotta-pin-shortcut--active': isPinned }"
    :is-loading="isSaving"
    :aria-pressed="isPinned"
    @click="togglePin"
  />
</template>

<style scoped>
.rotta-pin-shortcut--active {
  color: #c026d3;
  outline: 1px solid rgb(192 38 211 / 45%);
  box-shadow: 0 0 0 2px rgb(192 38 211 / 10%);
}

.rotta-pin-shortcut--active:hover {
  background: rgb(192 38 211 / 12%);
}

@media (max-width: 640px) {
  .rotta-pin-shortcut :deep(button) {
    padding-inline: 0.5rem;
  }
}
</style>
