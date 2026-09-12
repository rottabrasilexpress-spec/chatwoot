<script setup>
import { computed, ref, watch } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SectionLayout from '../account/components/SectionLayout.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Switch from 'next/switch/Switch.vue';
import { canViewCalculator } from './calculatorVisibility';

const { currentAccount, updateAccount } = useAccount();
const currentUserId = useMapGetter('getCurrentUserID');

const calculatorCopy = {
  title: 'Calculadora',
  headerDescription:
    'Área reservada para a futura calculadora integrada à inteligência artificial.',
  visibilityTitle: 'Visibilidade para os agentes',
  visibilityDescription:
    'Quando ativada, a aba e a calculadora ficarão disponíveis para os demais agentes, incluindo o Caio. Desativada, somente este usuário continuará vendo o recurso.',
  preparationTitle: 'Preparação para a integração',
  preparationDescription:
    'A estrutura está preparada para receber a lógica de cálculo e a integração com a IA na próxima etapa.',
  preparationMessage:
    'A calculadora ainda não executa cálculos. Esta área será preenchida conforme as regras de negócio forem definidas.',
  privateMessage:
    'Esta Calculadora está disponível somente para o agente que a criou.',
};

const isShared = ref(false);

const calculatorSettings = computed(() => currentAccount.value?.settings || {});
const canView = computed(() =>
  canViewCalculator({
    shared: calculatorSettings.value.rotta_calculator_shared,
    ownerId: calculatorSettings.value.rotta_calculator_owner_id,
    currentUserId: currentUserId.value,
  })
);

watch(
  calculatorSettings,
  settings => {
    isShared.value = !!settings.rotta_calculator_shared;
  },
  { immediate: true }
);

const toggleVisibility = async () => {
  try {
    await updateAccount({ rotta_calculator_shared: isShared.value });
    useAlert('Visibilidade da Calculadora atualizada.');
  } catch {
    isShared.value = !isShared.value;
    useAlert('Não foi possível atualizar a visibilidade da Calculadora.');
  }
};
</script>

<template>
  <SettingsLayout>
    <template #header>
      <BaseSettingsHeader
        :title="calculatorCopy.title"
        :description="calculatorCopy.headerDescription"
      />
    </template>

    <template #body>
      <div v-if="canView" class="flex flex-col gap-6 mt-4">
        <SectionLayout
          :title="calculatorCopy.visibilityTitle"
          :description="calculatorCopy.visibilityDescription"
          with-border
        >
          <template #headerActions>
            <div class="flex justify-end">
              <Switch v-model="isShared" @change="toggleVisibility" />
            </div>
          </template>
        </SectionLayout>

        <SectionLayout
          :title="calculatorCopy.preparationTitle"
          :description="calculatorCopy.preparationDescription"
        >
          <div
            class="rounded-xl border border-dashed border-n-strong bg-n-alpha-1 p-5 text-sm text-n-slate-11"
          >
            {{ calculatorCopy.preparationMessage }}
          </div>
        </SectionLayout>
      </div>
      <div v-else class="py-20 text-center text-sm text-n-slate-11">
        {{ calculatorCopy.privateMessage }}
      </div>
    </template>
  </SettingsLayout>
</template>
