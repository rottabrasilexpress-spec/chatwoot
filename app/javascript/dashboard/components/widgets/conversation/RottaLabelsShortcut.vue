<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, ref } from 'vue';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useConversationLabels } from 'dashboard/composables/useConversationLabels';
import Button from 'dashboard/components-next/button/Button.vue';
import LabelDropdown from 'shared/components/ui/label/LabelDropdown.vue';

const { isAdmin } = useAdmin();
const isOpen = ref(false);

const {
  accountLabels,
  savedLabels,
  addLabelToConversation,
  removeLabelFromConversation,
} = useConversationLabels();

const hasKelvinCaio = computed(() => savedLabels.value.includes('kelvin-caio'));

const toggle = () => {
  isOpen.value = !isOpen.value;
};

const close = () => {
  isOpen.value = false;
};
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <div
    v-on-clickaway="close"
    class="relative flex items-center rotta-labels-shortcut"
  >
    <Button
      v-tooltip="'Etiquetas'"
      size="sm"
      variant="ghost"
      color="slate"
      icon="i-lucide-tags"
      label="Etiquetas"
      class="whitespace-nowrap rounded-md"
      :class="{
        'rotta-labels-shortcut--priority': hasKelvinCaio,
      }"
      :aria-expanded="isOpen"
      aria-haspopup="menu"
      @click="toggle"
    />

    <div
      v-if="isOpen"
      class="absolute z-[100] top-full mt-2 ltr:right-0 rtl:left-0 w-[min(18rem,calc(100vw-1rem))] p-2 border rounded-xl shadow-xl bg-n-alpha-3 backdrop-blur-xl border-n-strong"
      role="menu"
    >
      <div class="flex items-center justify-between px-1 pb-2">
        <span class="text-xs font-medium text-n-slate-12">
          Etiquetas do cliente
        </span>
        <span class="text-xxs text-n-slate-11">
          {{ savedLabels.length }} selecionada(s)
        </span>
      </div>
      <LabelDropdown
        :account-labels="accountLabels"
        :selected-labels="savedLabels"
        :allow-creation="isAdmin"
        @add="addLabelToConversation"
        @remove="removeLabelFromConversation"
      />
    </div>
  </div>
</template>

<style scoped>
.rotta-labels-shortcut--priority {
  color: #c026d3;
  outline: 1px solid rgb(192 38 211 / 45%);
  box-shadow: 0 0 0 2px rgb(192 38 211 / 10%);
}

.rotta-labels-shortcut--priority:hover {
  background: rgb(192 38 211 / 12%);
}

@media (max-width: 640px) {
  .rotta-labels-shortcut :deep(button) {
    padding-inline: 0.5rem;
  }
}
</style>
