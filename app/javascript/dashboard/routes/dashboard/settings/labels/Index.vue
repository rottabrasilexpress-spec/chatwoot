<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { useAlert } from 'dashboard/composables';
import { computed, onBeforeMount, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import { picoSearch } from '@chatwoot/pico-search';
import rottaFollowUpAPI from 'dashboard/api/rottaFollowUp';
import rottaAutomaticLabelsAPI from 'dashboard/api/rottaAutomaticLabels';
import {
  canonicalFollowUpStage,
  CONFIGURED_DELAY_HOURS,
  FOLLOW_UP_STAGE_TITLES,
  orderedFollowUpStages,
  orderedTrailStages,
} from './followUpHelpers';

import AddLabel from './AddLabel.vue';
import EditLabel from './EditLabel.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';
import {
  LABEL_PRESENTATION_OPTIONS,
  useLabelPresentation,
} from 'dashboard/helper/rottaLabelPresentation';

const getters = useStoreGetters();
const store = useStore();
const { t } = useI18n();

const loading = ref({});
const showAddPopup = ref(false);
const showEditPopup = ref(false);
const showDeleteConfirmationPopup = ref(false);
const selectedLabel = ref({});
const searchQuery = ref('');
const records = computed(() => getters['labels/getLabels'].value);
const followUpConfigLoading = ref(false);
const automationLoading = ref(false);
const automationSaving = ref(false);
const automationSettings = ref({
  first_contact: false,
  kelvin: false,
  caio_attention: false,
});
const automationLogs = ref([]);
const pendingAutomation = ref(null);
const showAutomationConfirmation = ref(false);
const automationOptions = [
  {
    key: 'first_contact',
    title: 'Primeiro contato',
    description:
      'Identifica a primeira mensagem do cliente e inicia a trilha de contato.',
  },
  {
    key: 'kelvin',
    title: 'KELVIN',
    description:
      'Após o pré-orçamento confirmado, aplica KELVIN e encerra Primeiro contato.',
  },
  {
    key: 'caio_attention',
    title: 'Caio Atenção',
    description:
      'Na trilha de orçamento, sinaliza pedidos que precisam de atendimento humano.',
  },
];
const followUpConfigUnavailable = ref(false);
const followUpConfigSaving = ref({});
const { presentation, setPresentation } = useLabelPresentation();
const fallbackFollowUpConfig = () =>
  Object.entries(CONFIGURED_DELAY_HOURS).map(([stageLabel, hours]) => ({
    stage_label: stageLabel,
    delay_minutes: hours * 60,
    enabled: true,
  }));

const followUpConfig = ref(fallbackFollowUpConfig());

const slugForLabel = value =>
  String(value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[✅❌🫶💰🤝]/gu, '')
    .trim()
    .replace(/\s+/g, '-');

const durationPartsFor = totalMinutes => {
  const safeMinutes = Math.max(0, Number(totalMinutes) || 0);
  return {
    days: Math.floor(safeMinutes / 1440),
    hours: Math.floor((safeMinutes % 1440) / 60),
    minutes: safeMinutes % 60,
  };
};

const normaliseFollowUpConfig = row => {
  const stageLabel = row.stage_label || row.label || row.slug;
  const delayMinutes =
    Number(row.delay_minutes) || Number(row.delay_hours || 0) * 60;
  return {
    ...row,
    stage_label: stageLabel,
    delay_minutes: Math.max(0, delayMinutes),
    enabled: row.enabled !== false,
    ...durationPartsFor(delayMinutes),
  };
};

const mergeFollowUpConfig = rows => {
  const incomingRows = Array.isArray(rows)
    ? rows.map(normaliseFollowUpConfig)
    : [];
  const incomingByStage = new Map(
    incomingRows.map(row => [canonicalFollowUpStage(row.stage_label), row])
  );
  const fallbackRows = fallbackFollowUpConfig();
  const fallbackStages = new Set(
    fallbackRows.map(row => canonicalFollowUpStage(row.stage_label))
  );
  const mergedRows = fallbackRows.map(
    row =>
      incomingByStage.get(canonicalFollowUpStage(row.stage_label)) ||
      normaliseFollowUpConfig(row)
  );
  const additionalRows = incomingRows.filter(
    row => !fallbackStages.has(canonicalFollowUpStage(row.stage_label))
  );
  return [...mergedRows, ...additionalRows];
};

const followUpConfigRows = computed(() => {
  const stages = orderedFollowUpStages(
    followUpConfig.value.map(row => row.stage_label)
  );
  return stages.map(stage => {
    const row = followUpConfig.value.find(item => item.stage_label === stage);
    return normaliseFollowUpConfig(row || { stage_label: stage });
  });
});

const followUpConfigSections = computed(() => {
  const rowsForTrail = trailKey => {
    const orderedStages = orderedTrailStages(
      followUpConfigRows.value.map(row => row.stage_label),
      trailKey
    );
    return orderedStages
      .map(stage =>
        followUpConfigRows.value.find(
          row => canonicalFollowUpStage(row.stage_label) === stage
        )
      )
      .filter(Boolean);
  };
  const sections = [
    {
      key: 'contact',
      title: 'Trilha de contato',
      description: 'Cadência para o primeiro atendimento e os lembretes.',
      rows: rowsForTrail('contact'),
    },
    {
      key: 'budget',
      title: 'Trilha de orçamento',
      description: 'Etapas de orçamento, tentativas e reativações.',
      rows: rowsForTrail('budget'),
    },
  ];

  return sections;
});

const labelForStage = stage =>
  records.value.find(label => slugForLabel(label.title) === stage) || null;

const stageTitle = stage =>
  FOLLOW_UP_STAGE_TITLES[canonicalFollowUpStage(stage)] ||
  labelForStage(stage)?.title ||
  stage;

const loadFollowUpConfig = async () => {
  followUpConfigLoading.value = true;
  followUpConfigUnavailable.value = false;
  try {
    const response = await rottaFollowUpAPI.create({ action: 'config' });
    const body = response.data || {};
    if (Array.isArray(body.config) && body.config.length) {
      followUpConfig.value = mergeFollowUpConfig(body.config);
    }
  } catch (error) {
    followUpConfigUnavailable.value = true;
  } finally {
    followUpConfigLoading.value = false;
  }
};

const loadAutomationSettings = async () => {
  automationLoading.value = true;
  try {
    const { data } = await rottaAutomaticLabelsAPI.getSettings();
    automationSettings.value = {
      ...automationSettings.value,
      ...data.settings,
    };
    automationLogs.value = data.logs || [];
  } catch (error) {
    useAlert(
      error?.message || 'Não foi possível carregar as etiquetas automáticas.'
    );
  } finally {
    automationLoading.value = false;
  }
};

const requestAutomationChange = option => {
  pendingAutomation.value = {
    ...option,
    enabled: !automationSettings.value[option.key],
  };
  showAutomationConfirmation.value = true;
};

const closeAutomationConfirmation = () => {
  showAutomationConfirmation.value = false;
  pendingAutomation.value = null;
};

const confirmAutomationChange = async () => {
  if (!pendingAutomation.value) return;
  automationSaving.value = true;
  const next = {
    ...automationSettings.value,
    [pendingAutomation.value.key]: pendingAutomation.value.enabled,
  };
  try {
    const { data } = await rottaAutomaticLabelsAPI.updateSettings({
      settings: next,
    });
    automationSettings.value = data.settings;
    automationLogs.value = data.logs || automationLogs.value;
    useAlert(
      `${pendingAutomation.value.title} ${pendingAutomation.value.enabled ? 'ativada' : 'desativada'}.`
    );
    closeAutomationConfirmation();
  } catch (error) {
    useAlert(
      error?.message || 'Não foi possível alterar a automação. Tente novamente.'
    );
  } finally {
    automationSaving.value = false;
  }
};

const automationStatusLabel = status =>
  ({
    applied: 'Aplicada',
    failed: 'Falha',
    blocked: 'Bloqueada',
    skipped: 'Ignorada',
    no_op: 'Sem alteração',
  })[status] || status;

const configDelayMinutes = row => {
  const days = Math.max(0, Number(row.days) || 0);
  const hours = Math.max(0, Number(row.hours) || 0);
  const minutes = Math.max(0, Number(row.minutes) || 0);
  return days * 1440 + hours * 60 + minutes;
};

const saveFollowUpConfig = async row => {
  const delayMinutes = configDelayMinutes(row);
  const key = row.stage_label;
  followUpConfigSaving.value[key] = true;
  try {
    const response = await rottaFollowUpAPI.create({
      action: 'config',
      config: [
        {
          stage_label: key,
          delay_minutes: delayMinutes,
          enabled: row.enabled,
        },
      ],
    });
    const body = response.data || {};
    if (Array.isArray(body.config) && body.config.length) {
      followUpConfig.value = mergeFollowUpConfig(body.config);
    } else {
      Object.assign(row, {
        delay_minutes: delayMinutes,
        ...durationPartsFor(delayMinutes),
      });
    }
    useAlert(`Configuração de ${stageTitle(key)} salva.`);
  } catch (error) {
    useAlert(error?.message || 'Não foi possível salvar o delay da etiqueta.');
  } finally {
    followUpConfigSaving.value[key] = false;
  }
};

const filteredRecords = computed(() => {
  const query = searchQuery.value.trim();
  if (!query) return records.value;
  return picoSearch(records.value, query, [
    { name: 'title', weight: 4 },
    'description',
  ]);
});
const uiFlags = computed(() => getters['labels/getUIFlags'].value);

const deleteMessage = computed(() => ` ${selectedLabel.value.title}?`);

const openAddPopup = () => {
  showAddPopup.value = true;
};
const hideAddPopup = () => {
  showAddPopup.value = false;
};

const openEditPopup = response => {
  showEditPopup.value = true;
  selectedLabel.value = response;
};
const hideEditPopup = () => {
  showEditPopup.value = false;
};

const openDeletePopup = response => {
  showDeleteConfirmationPopup.value = true;
  selectedLabel.value = response;
};
const closeDeletePopup = () => {
  showDeleteConfirmationPopup.value = false;
};

const deleteLabel = async id => {
  try {
    await store.dispatch('labels/delete', id);
    useAlert(t('LABEL_MGMT.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    const errorMessage =
      error?.message || t('LABEL_MGMT.DELETE.API.ERROR_MESSAGE');
    useAlert(errorMessage);
  } finally {
    loading.value[selectedLabel.value.id] = false;
  }
};

const confirmDeletion = () => {
  loading.value[selectedLabel.value.id] = true;
  closeDeletePopup();
  deleteLabel(selectedLabel.value.id);
};

const tableHeaders = computed(() => {
  return [
    t('LABEL_MGMT.LIST.TABLE_HEADER.NAME'),
    t('LABEL_MGMT.LIST.TABLE_HEADER.DESCRIPTION'),
    t('LABEL_MGMT.LIST.TABLE_HEADER.COLOR'),
    t('LABEL_MGMT.LIST.TABLE_HEADER.ACTION'),
  ];
});

onBeforeMount(async () => {
  await store.dispatch('labels/get');
  await Promise.all([loadFollowUpConfig(), loadAutomationSettings()]);
});
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="$t('LABEL_MGMT.LOADING')"
    :no-records-found="!records.length"
    :no-records-message="$t('LABEL_MGMT.LIST.404')"
  >
    <template #header>
      <BaseSettingsHeader
        v-model:search-query="searchQuery"
        :title="$t('LABEL_MGMT.HEADER')"
        :description="$t('LABEL_MGMT.DESCRIPTION')"
        :link-text="$t('LABEL_MGMT.LEARN_MORE')"
        :search-placeholder="$t('LABEL_MGMT.SEARCH_PLACEHOLDER')"
        feature-name="labels"
      >
        <template v-if="records?.length" #count>
          <span class="text-body-main text-n-slate-11">
            {{ $t('LABEL_MGMT.COUNT', { n: records.length }) }}
          </span>
        </template>
        <template #actions>
          <Button
            :label="$t('LABEL_MGMT.HEADER_BTN_TXT')"
            size="sm"
            @click="openAddPopup"
          />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <section
        class="rotta-automation-panel"
        aria-labelledby="rotta-automation-title"
      >
        <div class="rotta-automation-panel__header">
          <div>
            <h2 id="rotta-automation-title">Etiquetas automáticas</h2>
            <p>
              Controle cada regra separadamente. As três começam desativadas e
              toda mudança exige confirmação.
            </p>
          </div>
          <span class="rotta-automation-recommendation">
            Recomendado: ativar as três
          </span>
        </div>

        <div v-if="automationLoading" class="rotta-config-loading">
          Carregando automações…
        </div>
        <div v-else class="rotta-automation-options">
          <article
            v-for="option in automationOptions"
            :key="option.key"
            class="rotta-automation-option"
          >
            <div class="rotta-automation-option__copy">
              <strong>{{ option.title }}</strong>
              <p>{{ option.description }}</p>
            </div>
            <button
              type="button"
              class="rotta-automation-switch"
              :class="{ 'is-active': automationSettings[option.key] }"
              :aria-pressed="automationSettings[option.key]"
              :aria-label="`${automationSettings[option.key] ? 'Desativar' : 'Ativar'} ${option.title}`"
              @click="requestAutomationChange(option)"
            >
              <span />
              {{ automationSettings[option.key] ? 'Ativada' : 'Desativada' }}
            </button>
          </article>
        </div>

        <details class="rotta-automation-logs">
          <summary>Ver registros recentes de aplicação e erros</summary>
          <div v-if="!automationLogs.length" class="rotta-automation-empty">
            Nenhuma execução registrada ainda.
          </div>
          <div v-else class="rotta-automation-log-list">
            <div
              v-for="log in automationLogs"
              :key="log.id"
              class="rotta-automation-log"
            >
              <span :class="`is-${log.status}`">{{
                automationStatusLabel(log.status)
              }}</span>
              <strong>{{ log.automation_key }}</strong>
              <a
                :href="`/app/accounts/${getters.getCurrentAccountId.value}/conversations/${log.conversation_id}`"
              >
                Conversa #{{ log.conversation_id }}
              </a>
              <p v-if="log.error_message">{{ log.error_message }}</p>
            </div>
          </div>
        </details>
      </section>

      <section
        class="rotta-label-style-panel"
        aria-labelledby="rotta-label-style-title"
      >
        <div class="rotta-label-style-panel__header">
          <div>
            <h2 id="rotta-label-style-title">
              Identidade visual das etiquetas
            </h2>
            <p>
              Escolha como as etiquetas aparecem no atendimento. A alteração é
              aplicada imediatamente nesta conta e neste navegador.
            </p>
          </div>
          <span class="rotta-label-style-live">Atualiza na hora</span>
        </div>

        <div
          class="rotta-label-style-options"
          role="radiogroup"
          aria-label="Estética das etiquetas"
        >
          <button
            v-for="option in LABEL_PRESENTATION_OPTIONS"
            :key="option.value"
            type="button"
            role="radio"
            class="rotta-label-style-option"
            :class="{
              'is-selected': presentation === option.value,
            }"
            :aria-checked="presentation === option.value"
            @click="setPresentation(option.value)"
          >
            <span
              class="rotta-label-style-preview"
              :class="`rotta-label-style-preview--${option.value}`"
            >
              <span class="rotta-label-style-sample">
                <span class="rotta-label-style-sample__dot" />
                Primeiro contato
              </span>
            </span>
            <span class="rotta-label-style-option__name">
              {{ option.label }}
            </span>
            <span class="rotta-label-style-option__description">
              {{ option.description }}
            </span>
          </button>
        </div>
      </section>

      <section class="rotta-config-panel" aria-labelledby="rotta-config-title">
        <div class="rotta-config-panel__header">
          <div>
            <h2 id="rotta-config-title">Motor de follow-up</h2>
            <p>
              Ajuste a janela de cada etiqueta. O n8n continua responsável por
              executar os envios no WhatsApp.
            </p>
          </div>
          <span v-if="followUpConfigUnavailable" class="rotta-config-note">
            Padrões locais · sincronização indisponível
          </span>
        </div>

        <div v-if="followUpConfigLoading" class="rotta-config-loading">
          Carregando configurações…
        </div>
        <div v-else class="rotta-config-list">
          <section
            v-for="section in followUpConfigSections"
            :key="section.key"
            class="rotta-config-section"
          >
            <div class="rotta-config-section__header">
              <div>
                <h3>{{ section.title }}</h3>
                <p>{{ section.description }}</p>
              </div>
              <span class="rotta-config-section__count">
                {{ section.rows.length }} etapas
              </span>
            </div>
            <div class="rotta-config-section__rows">
              <article
                v-for="row in section.rows"
                :key="row.stage_label"
                class="rotta-config-row"
              >
                <div class="rotta-config-row__label">
                  <span class="rotta-config-row__dot" />
                  <div>
                    <strong>{{ stageTitle(row.stage_label) }}</strong>
                    <small>{{ row.stage_label }}</small>
                  </div>
                </div>
                <label class="rotta-config-toggle">
                  <input v-model="row.enabled" type="checkbox" />
                  <span>Ativo</span>
                </label>
                <div
                  class="rotta-config-duration"
                  aria-label="Delay da etiqueta"
                >
                  <label>
                    <span>Dias</span>
                    <input
                      v-model.number="row.days"
                      type="number"
                      min="0"
                      max="365"
                      inputmode="numeric"
                    />
                  </label>
                  <label>
                    <span>Horas</span>
                    <input
                      v-model.number="row.hours"
                      type="number"
                      min="0"
                      max="23"
                      inputmode="numeric"
                    />
                  </label>
                  <label>
                    <span>Minutos</span>
                    <input
                      v-model.number="row.minutes"
                      type="number"
                      min="0"
                      max="59"
                      inputmode="numeric"
                    />
                  </label>
                </div>
                <Button
                  label="Salvar"
                  size="sm"
                  :is-loading="followUpConfigSaving[row.stage_label]"
                  @click="saveFollowUpConfig(row)"
                />
              </article>
            </div>
          </section>
        </div>
      </section>

      <div class="rotta-labels-table-shell">
        <BaseTable
          :headers="tableHeaders"
          :items="filteredRecords"
          :no-data-message="
            searchQuery
              ? $t('LABEL_MGMT.NO_RESULTS')
              : $t('LABEL_MGMT.LIST.404')
          "
        >
          <template #row="{ items }">
            <BaseTableRow
              v-for="label in items"
              :key="label.title"
              :item="label"
            >
              <template #default>
                <BaseTableCell>
                  <span class="text-body-main text-n-slate-12">
                    {{ label.title }}
                  </span>
                </BaseTableCell>

                <BaseTableCell>
                  <span class="text-body-main text-n-slate-11">
                    {{ label.description }}
                  </span>
                </BaseTableCell>

                <BaseTableCell>
                  <div class="flex items-center">
                    <span
                      class="w-4 h-4 ltr:mr-2 rtl:ml-2 border border-solid rounded border-n-weak"
                      :style="{ backgroundColor: label.color }"
                    />
                    <span class="text-body-main text-n-slate-12">
                      {{ label.color }}
                    </span>
                  </div>
                </BaseTableCell>

                <BaseTableCell align="end">
                  <div class="flex gap-3 justify-end flex-shrink-0">
                    <Button
                      v-tooltip.top="$t('LABEL_MGMT.FORM.EDIT')"
                      icon="i-woot-edit-pen"
                      slate
                      sm
                      :is-loading="loading[label.id]"
                      @click="openEditPopup(label)"
                    />
                    <Button
                      v-tooltip.top="$t('LABEL_MGMT.FORM.DELETE')"
                      icon="i-woot-bin"
                      slate
                      sm
                      class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                      :is-loading="loading[label.id]"
                      @click="openDeletePopup(label)"
                    />
                  </div>
                </BaseTableCell>
              </template>
            </BaseTableRow>
          </template>
        </BaseTable>
      </div>
    </template>

    <woot-modal v-model:show="showAddPopup" :on-close="hideAddPopup">
      <AddLabel @close="hideAddPopup" />
    </woot-modal>

    <woot-modal v-model:show="showEditPopup" :on-close="hideEditPopup">
      <EditLabel :selected-response="selectedLabel" @close="hideEditPopup" />
    </woot-modal>

    <woot-modal
      v-model:show="showAutomationConfirmation"
      :on-close="closeAutomationConfirmation"
    >
      <div v-if="pendingAutomation" class="rotta-automation-confirmation">
        <h3>
          {{ pendingAutomation.enabled ? 'Ativar' : 'Desativar' }}
          {{ pendingAutomation.title }}?
        </h3>
        <p>{{ pendingAutomation.description }}</p>
        <p class="rotta-automation-confirmation__notice">
          Para manter a passagem completa entre as etapas, recomendamos ativar
          Primeiro contato, KELVIN e Caio Atenção juntas.
        </p>
        <p v-if="!pendingAutomation.enabled">
          A desativação vale somente para eventos futuros. Etiquetas já
          aplicadas não serão removidas.
        </p>
        <div class="rotta-automation-confirmation__actions">
          <Button label="Cancelar" slate @click="closeAutomationConfirmation" />
          <Button
            :label="
              pendingAutomation.enabled
                ? 'Confirmar ativação'
                : 'Confirmar desativação'
            "
            :is-loading="automationSaving"
            @click="confirmAutomationChange"
          />
        </div>
      </div>
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeleteConfirmationPopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="$t('LABEL_MGMT.DELETE.CONFIRM.TITLE')"
      :message="$t('LABEL_MGMT.DELETE.CONFIRM.MESSAGE')"
      :message-value="deleteMessage"
      :confirm-text="$t('LABEL_MGMT.DELETE.CONFIRM.YES')"
      :reject-text="$t('LABEL_MGMT.DELETE.CONFIRM.NO')"
    />
  </SettingsLayout>
</template>

<style scoped>
.rotta-automation-panel {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  margin-bottom: 1rem;
  padding: 1rem;
  @apply bg-n-solid-2 border border-n-weak rounded-2xl;
}
.rotta-automation-panel__header {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  align-items: flex-start;
}
.rotta-automation-panel h2 {
  margin: 0;
  font-size: 1rem;
  font-weight: 700;
  @apply text-n-slate-12;
}
.rotta-automation-panel p {
  margin: 0.3rem 0 0;
  max-width: 68ch;
  font-size: 0.75rem;
  line-height: 1.45;
  @apply text-n-slate-11;
}
.rotta-automation-recommendation {
  flex: 0 0 auto;
  padding: 0.35rem 0.6rem;
  border-radius: 999px;
  font-size: 0.7rem;
  font-weight: 650;
  @apply bg-n-amber-3 text-n-amber-11;
}
.rotta-automation-options {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0.75rem;
}
.rotta-automation-option {
  display: flex;
  min-width: 0;
  flex-direction: column;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.85rem;
  border-radius: 0.85rem;
  @apply bg-n-solid-1 border border-n-weak;
}
.rotta-automation-option__copy strong {
  @apply text-n-slate-12;
}
.rotta-automation-switch {
  display: inline-flex;
  align-items: center;
  align-self: flex-start;
  gap: 0.45rem;
  min-height: 2rem;
  padding: 0.3rem 0.6rem;
  border-radius: 999px;
  font-size: 0.72rem;
  font-weight: 650;
  @apply bg-n-slate-3 text-n-slate-11;
}
.rotta-automation-switch span {
  width: 0.65rem;
  height: 0.65rem;
  border-radius: 50%;
  @apply bg-n-slate-8;
}
.rotta-automation-switch.is-active {
  @apply bg-n-teal-3 text-n-teal-11;
}
.rotta-automation-switch.is-active span {
  @apply bg-n-teal-9;
}
.rotta-automation-switch:focus-visible {
  outline: 2px solid rgb(var(--blue-9));
  outline-offset: 2px;
}
.rotta-automation-logs {
  padding-top: 0.2rem;
}
.rotta-automation-logs summary {
  cursor: pointer;
  font-size: 0.75rem;
  font-weight: 650;
  @apply text-n-slate-12;
}
.rotta-automation-empty {
  margin-top: 0.75rem;
  font-size: 0.75rem;
  @apply text-n-slate-10;
}
.rotta-automation-log-list {
  display: grid;
  gap: 0.45rem;
  margin-top: 0.75rem;
}
.rotta-automation-log {
  display: grid;
  grid-template-columns: 6rem 8rem 1fr;
  gap: 0.6rem;
  align-items: center;
  min-width: 0;
  padding: 0.55rem 0.65rem;
  border-radius: 0.65rem;
  font-size: 0.72rem;
  @apply bg-n-solid-1 border border-n-weak text-n-slate-11;
}
.rotta-automation-log p {
  grid-column: 1 / -1;
  margin: 0;
  overflow-wrap: anywhere;
  @apply text-n-ruby-11;
}
.rotta-automation-log > span {
  font-weight: 650;
}
.rotta-automation-log > span.is-failed {
  @apply text-n-ruby-11;
}
.rotta-automation-log > span.is-applied {
  @apply text-n-teal-11;
}
.rotta-automation-confirmation {
  padding: 1.25rem;
  max-width: 34rem;
}
.rotta-automation-confirmation h3 {
  margin: 0;
  font-size: 1.1rem;
  @apply text-n-slate-12;
}
.rotta-automation-confirmation p {
  line-height: 1.5;
  @apply text-n-slate-11;
}
.rotta-automation-confirmation__notice {
  padding: 0.75rem;
  border-radius: 0.75rem;
  @apply bg-n-amber-3 text-n-amber-12;
}
.rotta-automation-confirmation__actions {
  display: flex;
  justify-content: flex-end;
  gap: 0.6rem;
  margin-top: 1rem;
}
@media (max-width: 767px) {
  .rotta-automation-panel__header {
    flex-direction: column;
  }
  .rotta-automation-options {
    grid-template-columns: 1fr;
  }
  .rotta-automation-log {
    grid-template-columns: 1fr;
  }
  .rotta-automation-log p {
    grid-column: auto;
  }
}
.rotta-label-style-panel {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  margin-bottom: 1rem;
  padding: 1rem;
  @apply bg-n-solid-2 border border-n-weak rounded-2xl;
}

.rotta-label-style-panel__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
}

.rotta-label-style-panel h2 {
  margin: 0;
  @apply text-n-slate-12;
  font-size: 1rem;
  font-weight: 700;
}

.rotta-label-style-panel p {
  max-width: 62ch;
  margin: 0.35rem 0 0;
  @apply text-n-slate-11;
  font-size: 0.72rem;
  line-height: 1.35;
}

.rotta-label-style-live {
  flex: 0 0 auto;
  padding: 0.3rem 0.55rem;
  @apply bg-n-teal-2 text-n-teal-11;
  border-radius: 999px;
  font-size: 0.68rem;
  font-weight: 650;
  white-space: nowrap;
}

.rotta-label-style-options {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 0.65rem;
}

.rotta-label-style-option {
  display: flex;
  min-width: 0;
  flex-direction: column;
  align-items: stretch;
  gap: 0.4rem;
  padding: 0.65rem;
  @apply bg-n-solid-1 border border-n-weak text-n-slate-12;
  border-radius: 0.85rem;
  text-align: start;
  transition:
    border-color 140ms ease,
    box-shadow 140ms ease,
    background-color 140ms ease;
}

.rotta-label-style-option:hover {
  @apply border-n-strong;
  box-shadow: 0 2px 8px rgb(15 23 42 / 7%);
}

.rotta-label-style-option:focus-visible {
  outline: 2px solid rgb(var(--blue-9));
  outline-offset: 2px;
}

.rotta-label-style-option.is-selected {
  @apply border-n-brand bg-n-brand/10;
  box-shadow: 0 0 0 1px rgb(var(--blue-9) / 18%);
}

.rotta-label-style-preview {
  display: flex;
  min-height: 3rem;
  align-items: center;
  justify-content: center;
  padding: 0.45rem;
  @apply bg-n-surface-2 border border-n-weak;
  border-radius: 0.6rem;
}

.rotta-label-style-sample {
  display: inline-flex;
  max-width: 100%;
  align-items: center;
  gap: 0.35rem;
  padding: 0.22rem 0.5rem;
  overflow: hidden;
  color: #166534;
  background: rgb(22 163 74 / 10%);
  border: 1px solid rgb(22 163 74 / 48%);
  border-radius: 4px;
  font-size: 0.68rem;
  font-weight: 650;
  line-height: 1rem;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.rotta-label-style-sample__dot {
  width: 0.42rem;
  height: 0.42rem;
  flex: 0 0 auto;
  background: #16a34a;
  border-radius: 999px;
}

.rotta-label-style-preview--round .rotta-label-style-sample {
  border-radius: 999px;
}

.rotta-label-style-preview--crisp .rotta-label-style-sample {
  border-color: #16a34a;
  box-shadow: 0 0 0 1px rgb(22 163 74 / 20%);
  font-weight: 750;
}

.rotta-label-style-preview--message-border .rotta-label-style-sample {
  background: #fff;
  border-color: #16a34a;
  border-radius: 0.65rem;
  box-shadow: 0 0 0 1px rgb(22 163 74 / 18%);
}

.rotta-label-style-option__name {
  font-size: 0.78rem;
  font-weight: 700;
}

.rotta-label-style-option__description {
  min-height: 2.1rem;
  @apply text-n-slate-11;
  font-size: 0.68rem;
  line-height: 1.35;
}

.rotta-config-panel {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  margin-bottom: 1rem;
  padding: 1rem;
  @apply bg-n-solid-2 border border-n-weak rounded-2xl;
}

.rotta-config-panel__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
}

.rotta-config-panel h2 {
  margin: 0;
  @apply text-n-slate-12;
  font-size: 1rem;
  font-weight: 700;
}

.rotta-config-panel p,
.rotta-config-note,
.rotta-config-row__label small,
.rotta-config-duration span {
  @apply text-n-slate-11;
  font-size: 0.72rem;
}

.rotta-config-panel p {
  margin: 0.35rem 0 0;
}

.rotta-config-note {
  flex: 0 0 auto;
  padding: 0.3rem 0.5rem;
  @apply bg-n-amber-2 text-n-amber-11;
  border-radius: 0.5rem;
}

.rotta-config-loading {
  padding: 1rem 0;
  @apply text-n-slate-11;
  font-size: 0.8rem;
}

.rotta-config-list {
  display: grid;
  gap: 1rem;
}

.rotta-config-section {
  display: flex;
  flex-direction: column;
  gap: 0.55rem;
}

.rotta-config-section__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  padding: 0 0.2rem;
}

.rotta-config-section__header h3 {
  margin: 0;
  @apply text-n-slate-12;
  font-size: 0.82rem;
  font-weight: 700;
}

.rotta-config-section__header p {
  margin: 0.2rem 0 0;
  @apply text-n-slate-11;
  font-size: 0.7rem;
}

.rotta-config-section__count {
  flex: 0 0 auto;
  padding: 0.25rem 0.5rem;
  @apply text-n-slate-11 bg-n-alpha-1;
  font-size: 0.68rem;
  border-radius: 999px;
}

.rotta-config-section__rows {
  display: grid;
  gap: 0.55rem;
}

.rotta-config-row {
  display: grid;
  grid-template-columns: minmax(12rem, 1.3fr) auto minmax(15rem, 1fr) auto;
  align-items: center;
  gap: 0.75rem;
  padding: 0.7rem;
  @apply bg-n-solid-1 border border-n-weak;
  border-radius: 1rem;
}

.rotta-labels-table-shell {
  overflow: hidden;
  @apply bg-n-solid-1 border border-n-weak;
  border-radius: 1rem;
}

.rotta-config-row__label,
.rotta-config-toggle,
.rotta-config-duration,
.rotta-config-duration label {
  display: flex;
  align-items: center;
}

.rotta-config-row__label {
  min-width: 0;
  gap: 0.55rem;
}

.rotta-config-row__label > div {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 0.15rem;
}

.rotta-config-row__label strong {
  overflow: hidden;
  @apply text-n-slate-12;
  font-size: 0.8rem;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.rotta-config-row__label small {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.rotta-config-row__dot {
  width: 0.55rem;
  height: 0.55rem;
  flex: 0 0 auto;
  @apply bg-n-brand;
  border-radius: 999px;
}

.rotta-config-toggle {
  gap: 0.35rem;
  @apply text-n-slate-11;
  font-size: 0.72rem;
  white-space: nowrap;
}

.rotta-config-toggle input {
  accent-color: rgb(var(--brand-9));
}

.rotta-config-duration {
  justify-content: flex-end;
  gap: 0.5rem;
}

.rotta-config-duration label {
  flex-direction: column;
  align-items: flex-start;
  gap: 0.2rem;
}

.rotta-config-duration input {
  width: 4.2rem;
  height: 2rem;
  padding: 0 0.4rem;
  @apply text-n-slate-12 bg-n-solid-1 border border-n-strong;
  font-size: 0.75rem;
  border-radius: 0.45rem;
}

@media (max-width: 900px) {
  .rotta-config-row {
    grid-template-columns: minmax(0, 1fr) auto;
  }

  .rotta-config-duration {
    grid-column: 1 / -1;
    justify-content: flex-start;
  }
}

@media (max-width: 640px) {
  .rotta-config-panel__header {
    flex-direction: column;
  }

  .rotta-config-section__header {
    flex-direction: column;
    gap: 0.45rem;
  }

  .rotta-config-row {
    grid-template-columns: 1fr;
    align-items: start;
  }

  .rotta-config-duration {
    width: 100%;
  }

  .rotta-config-duration label {
    flex: 1;
  }

  .rotta-config-duration input {
    width: 100%;
  }

  .rotta-config-row :deep(button) {
    width: 100%;
  }
}
</style>
