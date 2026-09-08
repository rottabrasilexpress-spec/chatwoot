<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { useAlert } from 'dashboard/composables';
import { computed, onBeforeMount, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import { picoSearch } from '@chatwoot/pico-search';
import rottaFollowUpAPI from 'dashboard/api/rottaFollowUp';
import { CONFIGURED_DELAY_HOURS, orderedFollowUpStages } from './followUpHelpers';

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
const followUpConfigUnavailable = ref(false);
const followUpConfigSaving = ref({});

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

const followUpConfigRows = computed(() => {
  const stages = orderedFollowUpStages(
    followUpConfig.value.map(row => row.stage_label)
  );
  return stages.map(stage => {
    const row = followUpConfig.value.find(item => item.stage_label === stage);
    return row || normaliseFollowUpConfig({ stage_label: stage });
  });
});

const labelForStage = stage =>
  records.value.find(label => slugForLabel(label.title) === stage) || null;

const stageTitle = stage => labelForStage(stage)?.title || stage;

const loadFollowUpConfig = async () => {
  followUpConfigLoading.value = true;
  followUpConfigUnavailable.value = false;
  try {
    const response = await rottaFollowUpAPI.create({ action: 'config' });
    const body = response.data || {};
    if (Array.isArray(body.config) && body.config.length) {
      followUpConfig.value = body.config.map(normaliseFollowUpConfig);
    }
  } catch (error) {
    followUpConfigUnavailable.value = true;
  } finally {
    followUpConfigLoading.value = false;
  }
};

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
      followUpConfig.value = body.config.map(normaliseFollowUpConfig);
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
  await loadFollowUpConfig();
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
          <article
            v-for="row in followUpConfigRows"
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
            <div class="rotta-config-duration" aria-label="Delay da etiqueta">
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

      <BaseTable
        :headers="tableHeaders"
        :items="filteredRecords"
        :no-data-message="
          searchQuery ? $t('LABEL_MGMT.NO_RESULTS') : $t('LABEL_MGMT.LIST.404')
        "
      >
        <template #row="{ items }">
          <BaseTableRow v-for="label in items" :key="label.title" :item="label">
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
    </template>

    <woot-modal v-model:show="showAddPopup" :on-close="hideAddPopup">
      <AddLabel @close="hideAddPopup" />
    </woot-modal>

    <woot-modal v-model:show="showEditPopup" :on-close="hideEditPopup">
      <EditLabel :selected-response="selectedLabel" @close="hideEditPopup" />
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
  gap: 0.55rem;
}

.rotta-config-row {
  display: grid;
  grid-template-columns: minmax(12rem, 1.3fr) auto minmax(15rem, 1fr) auto;
  align-items: center;
  gap: 0.75rem;
  padding: 0.7rem;
  @apply bg-n-solid-1 border border-n-weak;
  border-radius: 0.75rem;
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
