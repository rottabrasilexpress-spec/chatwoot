<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Switch from 'next/switch/Switch.vue';
import Modal from 'dashboard/components/Modal.vue';
import {
  canViewCalculator,
  getRequestedCalculatorVisibility,
  shouldClaimCalculatorOwnership,
} from './calculatorVisibility';
import { buildCalculationResult, parseInventory } from './calculatorHelpers';

const { t } = useI18n();
const { currentAccount, updateAccount } = useAccount();
const currentUserId = useMapGetter('getCurrentUserID');

const freight = reactive({
  clientName: '',
  date: '',
  origin: '',
  destination: '',
});

const serviceOptions = [
  { key: 'assembly', label: t('CALCULATOR.SERVICES.ASSEMBLY') },
  { key: 'packing', label: t('CALCULATOR.SERVICES.PACKING') },
  { key: 'disassembly', label: t('CALCULATOR.SERVICES.DISASSEMBLY') },
  { key: 'storage', label: t('CALCULATOR.SERVICES.STORAGE') },
  { key: 'insurance', label: t('CALCULATOR.SERVICES.INSURANCE') },
];

const services = reactive(
  Object.fromEntries(serviceOptions.map(service => [service.key, false]))
);
const readingText = ref('');
const inventoryText = ref('');
const result = ref(null);
const isShared = ref(false);
const showVisibilityConfirmModal = ref(false);
const pendingVisibility = ref(null);
const isSavingVisibility = ref(false);
const activeResultTab = ref('proposal');

const calculatorSettings = computed(() => currentAccount.value?.settings || {});
const canView = computed(() =>
  canViewCalculator({
    shared: calculatorSettings.value.rotta_calculator_shared,
    ownerId: calculatorSettings.value.rotta_calculator_owner_id,
    currentUserId: currentUserId.value,
  })
);

const inventorySummary = computed(() => parseInventory(inventoryText.value));

const selectedServices = computed(() =>
  serviceOptions.map(service => ({
    label: service.label,
    selected: services[service.key],
  }))
);

watch(
  calculatorSettings,
  settings => {
    isShared.value = !!settings.rotta_calculator_shared;
  },
  { immediate: true }
);

const ensureCalculatorOwnership = async () => {
  if (
    !shouldClaimCalculatorOwnership({
      ownerId: calculatorSettings.value.rotta_calculator_owner_id,
      currentUserId: currentUserId.value,
    })
  )
    return;

  try {
    await updateAccount({ rotta_calculator_shared: false }, { silent: true });
  } catch {
    // The visibility switch remains available when the account API is offline.
  }
};

const requestVisibilityChange = switchEventValue => {
  const requestedVisibility =
    getRequestedCalculatorVisibility(switchEventValue);

  // Keep the switch aligned with the persisted state until the agent confirms
  // the change in the modal.
  isShared.value = !requestedVisibility;
  pendingVisibility.value = requestedVisibility;
  showVisibilityConfirmModal.value = true;
};

const cancelVisibilityChange = () => {
  pendingVisibility.value = null;
  showVisibilityConfirmModal.value = false;
};

const confirmVisibilityChange = async () => {
  if (pendingVisibility.value === null || isSavingVisibility.value) return;

  const requestedVisibility = pendingVisibility.value;
  isSavingVisibility.value = true;
  isShared.value = requestedVisibility;
  showVisibilityConfirmModal.value = false;

  try {
    await updateAccount({ rotta_calculator_shared: requestedVisibility });
    useAlert(t('CALCULATOR.ALERTS.VISIBILITY_UPDATED'));
  } catch {
    isShared.value = !requestedVisibility;
    useAlert(t('CALCULATOR.ALERTS.VISIBILITY_ERROR'));
  } finally {
    pendingVisibility.value = null;
    isSavingVisibility.value = false;
  }
};

const clearCalculator = () => {
  readingText.value = '';
  inventoryText.value = '';
  Object.keys(freight).forEach(key => {
    freight[key] = '';
  });
  serviceOptions.forEach(service => {
    services[service.key] = false;
  });
  result.value = null;
  activeResultTab.value = 'proposal';
};

const calculate = () => {
  result.value = buildCalculationResult({
    freight,
    services: selectedServices.value,
    inventory: inventorySummary.value,
  });
};

const copyProposal = async () => {
  if (!result.value?.proposal) return;

  try {
    await navigator.clipboard.writeText(result.value.proposal);
    useAlert(t('CALCULATOR.ALERTS.PROPOSAL_COPIED'));
  } catch {
    useAlert(t('CALCULATOR.ALERTS.PROPOSAL_COPY_ERROR'));
  }
};

const copyInventory = async () => {
  if (!inventoryText.value.trim()) return;

  try {
    await navigator.clipboard.writeText(inventoryText.value.trim());
    useAlert(t('CALCULATOR.ALERTS.INVENTORY_COPIED'));
  } catch {
    useAlert(t('CALCULATOR.ALERTS.INVENTORY_COPY_ERROR'));
  }
};

onMounted(ensureCalculatorOwnership);
</script>

<template>
  <SettingsLayout>
    <template #header>
      <BaseSettingsHeader
        :title="t('CALCULATOR.TITLE')"
        :description="t('CALCULATOR.DESCRIPTION')"
      />
    </template>

    <template #body>
      <div v-if="canView" class="flex flex-col gap-6 mt-4">
        <section
          class="flex flex-col gap-4 p-5 border rounded-2xl border-n-weak bg-n-solid-1 sm:flex-row sm:items-center sm:justify-between"
        >
          <div class="flex items-start gap-3">
            <div
              class="flex items-center justify-center flex-shrink-0 rounded-xl size-10 bg-n-brand/10 text-n-brand"
            >
              <Icon icon="i-lucide-shield-check" class="size-5" />
            </div>
            <div>
              <h2 class="text-base font-semibold text-n-slate-12">
                {{ t('CALCULATOR.SHARING.TITLE') }}
              </h2>
              <p class="mt-1 text-sm text-n-slate-11">
                {{ t('CALCULATOR.SHARING.DESCRIPTION') }}
              </p>
            </div>
          </div>
          <div class="flex items-center gap-3 shrink-0">
            <span class="text-sm font-medium text-n-slate-12">
              {{
                isShared
                  ? t('CALCULATOR.SHARING.SHARED')
                  : t('CALCULATOR.SHARING.PRIVATE')
              }}
            </span>
            <Switch
              v-model="isShared"
              data-testid="calculator-share-switch"
              @change="requestVisibilityChange"
            />
          </div>
        </section>

        <section
          class="flex flex-col gap-4 p-5 border rounded-2xl border-n-weak bg-n-solid-1"
        >
          <div class="flex items-start gap-3">
            <div
              class="flex items-center justify-center flex-shrink-0 rounded-xl size-10 bg-n-blue-3 text-n-blue-11"
            >
              <Icon icon="i-lucide-book-open" class="size-5" />
            </div>
            <div>
              <h2 class="text-base font-semibold text-n-slate-12">
                {{ t('CALCULATOR.READING.TITLE') }}
              </h2>
              <p class="mt-1 text-sm text-n-slate-11">
                {{ t('CALCULATOR.READING.DESCRIPTION') }}
              </p>
            </div>
          </div>
          <TextArea
            id="calculator-reading"
            v-model="readingText"
            :label="t('CALCULATOR.READING.LABEL')"
            :placeholder="t('CALCULATOR.READING.PLACEHOLDER')"
            min-height="11rem"
            max-height="22rem"
            resize
            data-testid="calculator-reading-input"
          />
          <div class="flex flex-wrap justify-end gap-3">
            <Button
              :label="t('CALCULATOR.ACTIONS.CLEAR')"
              variant="outline"
              color="slate"
              icon="i-lucide-eraser"
              data-testid="calculator-clear"
              @click="clearCalculator"
            />
            <Button
              :label="t('CALCULATOR.ACTIONS.CALCULATE')"
              color="blue"
              icon="i-lucide-calculator"
              data-testid="calculator-calculate"
              @click="calculate"
            />
          </div>
        </section>

        <div class="grid grid-cols-1 gap-6 xl:grid-cols-2">
          <section
            class="flex flex-col gap-5 p-5 border rounded-2xl border-n-weak bg-n-solid-1"
          >
            <div>
              <h2 class="text-base font-semibold text-n-slate-12">
                {{ t('CALCULATOR.FREIGHT.TITLE') }}
              </h2>
              <p class="mt-1 text-sm text-n-slate-11">
                {{ t('CALCULATOR.FREIGHT.DESCRIPTION') }}
              </p>
            </div>
            <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <Input
                v-model="freight.clientName"
                :label="t('CALCULATOR.FREIGHT.CLIENT')"
                :placeholder="t('CALCULATOR.FREIGHT.CLIENT_PLACEHOLDER')"
                data-testid="calculator-client"
              />
              <Input
                v-model="freight.date"
                :label="t('CALCULATOR.FREIGHT.DATE')"
                type="date"
                data-testid="calculator-date"
              />
              <Input
                v-model="freight.origin"
                :label="t('CALCULATOR.FREIGHT.ORIGIN')"
                :placeholder="t('CALCULATOR.FREIGHT.ORIGIN_PLACEHOLDER')"
                data-testid="calculator-origin"
              />
              <Input
                v-model="freight.destination"
                :label="t('CALCULATOR.FREIGHT.DESTINATION')"
                :placeholder="t('CALCULATOR.FREIGHT.DESTINATION_PLACEHOLDER')"
                data-testid="calculator-destination"
              />
            </div>
            <div>
              <h3 class="mb-3 text-sm font-semibold text-n-slate-12">
                {{ t('CALCULATOR.SERVICES.TITLE') }}
              </h3>
              <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
                <label
                  v-for="service in serviceOptions"
                  :key="service.key"
                  class="flex items-center gap-3 p-3 text-sm border rounded-lg cursor-pointer border-n-weak text-n-slate-12 hover:bg-n-alpha-2"
                >
                  <input
                    v-model="services[service.key]"
                    type="checkbox"
                    class="rounded border-n-strong text-n-brand focus:ring-n-brand"
                  />
                  <span>{{ service.label }}</span>
                </label>
              </div>
            </div>
          </section>

          <section
            class="flex flex-col gap-5 p-5 border rounded-2xl border-n-weak bg-n-solid-1"
          >
            <div>
              <h2 class="text-base font-semibold text-n-slate-12">
                {{ t('CALCULATOR.INVENTORY.TITLE') }}
              </h2>
              <p class="mt-1 text-sm text-n-slate-11">
                {{ t('CALCULATOR.INVENTORY.DESCRIPTION') }}
              </p>
            </div>
            <TextArea
              id="calculator-inventory"
              v-model="inventoryText"
              :label="t('CALCULATOR.INVENTORY.LABEL')"
              :placeholder="t('CALCULATOR.INVENTORY.PLACEHOLDER')"
              min-height="11rem"
              max-height="22rem"
              resize
              data-testid="calculator-inventory-input"
            />
            <div class="grid grid-cols-2 gap-3">
              <div class="p-3 rounded-lg bg-n-alpha-2">
                <p class="text-xs text-n-slate-11">
                  {{ t('CALCULATOR.INVENTORY.ITEMS') }}
                </p>
                <p class="mt-1 text-lg font-semibold text-n-slate-12">
                  {{ inventorySummary.itemCount }}
                </p>
              </div>
              <div class="p-3 rounded-lg bg-n-alpha-2">
                <p class="text-xs text-n-slate-11">
                  {{ t('CALCULATOR.INVENTORY.VOLUME') }}
                </p>
                <p class="mt-1 text-lg font-semibold text-n-slate-12">
                  {{
                    t('CALCULATOR.INVENTORY.VOLUME_VALUE', {
                      value: inventorySummary.volumeM3.toFixed(3),
                    })
                  }}
                </p>
              </div>
            </div>
          </section>
        </div>

        <section
          class="grid grid-cols-1 gap-4 p-5 border rounded-2xl border-dashed border-n-strong bg-n-alpha-1 lg:grid-cols-2"
        >
          <div class="flex items-start gap-3">
            <Icon
              icon="i-lucide-sparkles"
              class="flex-shrink-0 mt-0.5 size-5 text-n-brand"
            />
            <div>
              <h2 class="text-base font-semibold text-n-slate-12">
                {{ t('CALCULATOR.INTEGRATIONS.TITLE') }}
              </h2>
              <p class="mt-1 text-sm text-n-slate-11">
                {{ t('CALCULATOR.INTEGRATIONS.DESCRIPTION') }}
              </p>
            </div>
          </div>
          <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div class="p-3 border rounded-lg border-n-weak bg-n-solid-1">
              <p class="text-sm font-medium text-n-slate-12">
                {{ t('CALCULATOR.INTEGRATIONS.AI_TITLE') }}
              </p>
              <p class="mt-1 text-xs text-n-slate-11">
                {{ t('CALCULATOR.INTEGRATIONS.PENDING') }}
              </p>
            </div>
            <div class="p-3 border rounded-lg border-n-weak bg-n-solid-1">
              <p class="text-sm font-medium text-n-slate-12">
                {{ t('CALCULATOR.INTEGRATIONS.MAPS_TITLE') }}
              </p>
              <p class="mt-1 text-xs text-n-slate-11">
                {{ t('CALCULATOR.INTEGRATIONS.PENDING') }}
              </p>
            </div>
          </div>
        </section>

        <section
          v-if="result"
          class="flex flex-col gap-5 p-5 border rounded-2xl border-n-brand/40 bg-n-brand/5"
          data-testid="calculator-result"
        >
          <div>
            <h2 class="text-base font-semibold text-n-slate-12">
              {{ t('CALCULATOR.RESULT.TITLE') }}
            </h2>
            <p class="mt-1 text-sm text-n-slate-11">
              {{ t('CALCULATOR.RESULT.DESCRIPTION') }}
            </p>
          </div>
          <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
            <div class="p-4 rounded-lg bg-n-solid-1">
              <p class="text-xs text-n-slate-11">
                {{ t('CALCULATOR.RESULT.ROUTE') }}
              </p>
              <p class="mt-1 text-sm font-semibold text-n-slate-12">
                {{ result.route }}
              </p>
            </div>
            <div class="p-4 rounded-lg bg-n-solid-1">
              <p class="text-xs text-n-slate-11">
                {{ t('CALCULATOR.RESULT.PRICE') }}
              </p>
              <p class="mt-1 text-sm font-semibold text-n-slate-12">
                {{ t('CALCULATOR.RESULT.PRICE_PENDING') }}
              </p>
            </div>
            <div class="p-4 rounded-lg bg-n-solid-1">
              <p class="text-xs text-n-slate-11">
                {{ t('CALCULATOR.RESULT.SERVICES') }}
              </p>
              <p class="mt-1 text-sm font-semibold text-n-slate-12">
                {{
                  result.selectedServices.join(', ') ||
                  t('CALCULATOR.RESULT.NO_SERVICES')
                }}
              </p>
            </div>
          </div>
          <div
            class="grid grid-cols-1 gap-4 p-4 border border-dashed rounded-xl border-n-strong bg-n-alpha-1 lg:grid-cols-[1.2fr_0.8fr]"
            data-testid="calculator-route-preview"
          >
            <div>
              <div class="flex items-center gap-2">
                <Icon icon="i-lucide-map" class="size-4 text-n-brand" />
                <h3 class="text-sm font-semibold text-n-slate-12">
                  {{ t('CALCULATOR.RESULT.ROUTE_PREVIEW_TITLE') }}
                </h3>
              </div>
              <p class="mt-2 text-sm text-n-slate-11">
                {{ t('CALCULATOR.RESULT.ROUTE_PREVIEW_PENDING') }}
              </p>
              <div class="grid grid-cols-3 gap-2 mt-4">
                <div class="p-3 rounded-lg bg-n-solid-1">
                  <p class="text-xs text-n-slate-11">
                    {{ t('CALCULATOR.RESULT.DISTANCE') }}
                  </p>
                  <p class="mt-1 text-sm font-semibold text-n-slate-12">
                    {{ t('CALCULATOR.RESULT.PENDING_VALUE') }}
                  </p>
                </div>
                <div class="p-3 rounded-lg bg-n-solid-1">
                  <p class="text-xs text-n-slate-11">
                    {{ t('CALCULATOR.RESULT.DURATION') }}
                  </p>
                  <p class="mt-1 text-sm font-semibold text-n-slate-12">
                    {{ t('CALCULATOR.RESULT.PENDING_VALUE') }}
                  </p>
                </div>
                <div class="p-3 rounded-lg bg-n-solid-1">
                  <p class="text-xs text-n-slate-11">
                    {{ t('CALCULATOR.RESULT.TOLLS') }}
                  </p>
                  <p class="mt-1 text-sm font-semibold text-n-slate-12">
                    {{ t('CALCULATOR.RESULT.PENDING_VALUE') }}
                  </p>
                </div>
              </div>
            </div>
            <div
              class="flex flex-col items-center justify-center min-h-32 p-4 text-center rounded-lg bg-n-alpha-2"
              data-testid="calculator-map-placeholder"
            >
              <Icon
                icon="i-lucide-map-pin"
                class="mb-2 size-6 text-n-slate-10"
              />
              <p class="text-xs text-n-slate-11">
                {{ t('CALCULATOR.INTEGRATIONS.MAPS_TITLE') }}
              </p>
              <p class="mt-1 text-xs text-n-slate-10">
                {{ t('CALCULATOR.INTEGRATIONS.PENDING') }}
              </p>
            </div>
          </div>
          <div class="flex flex-col gap-3">
            <div class="flex flex-wrap items-center justify-between gap-3">
              <h3 class="text-sm font-semibold text-n-slate-12">
                {{ t('CALCULATOR.RESULT.PROPOSAL_TITLE') }}
              </h3>
              <div class="flex flex-wrap gap-2">
                <Button
                  :label="t('CALCULATOR.RESULT.PROPOSAL_TAB')"
                  :variant="
                    activeResultTab === 'proposal' ? 'solid' : 'outline'
                  "
                  color="slate"
                  size="sm"
                  data-testid="calculator-proposal-tab"
                  @click="activeResultTab = 'proposal'"
                />
                <Button
                  :label="t('CALCULATOR.RESULT.INVENTORY_TAB')"
                  :variant="
                    activeResultTab === 'inventory' ? 'solid' : 'outline'
                  "
                  color="slate"
                  size="sm"
                  data-testid="calculator-inventory-tab"
                  @click="activeResultTab = 'inventory'"
                />
              </div>
            </div>
            <div
              v-if="activeResultTab === 'proposal'"
              class="flex flex-col gap-3"
            >
              <div class="flex justify-end">
                <Button
                  :label="t('CALCULATOR.RESULT.COPY')"
                  variant="outline"
                  color="slate"
                  size="sm"
                  icon="i-lucide-copy"
                  data-testid="calculator-copy-proposal"
                  @click="copyProposal"
                />
              </div>
              <textarea
                :value="result.proposal"
                readonly
                rows="8"
                class="w-full p-4 text-sm border rounded-lg resize-y border-n-weak bg-n-solid-1 text-n-slate-12 focus:outline-none focus:ring-1 focus:ring-n-brand"
                data-testid="calculator-proposal"
              />
            </div>
            <div v-else class="flex flex-col gap-3">
              <div class="flex justify-end">
                <Button
                  :label="t('CALCULATOR.RESULT.INVENTORY_COPY')"
                  variant="outline"
                  color="slate"
                  size="sm"
                  icon="i-lucide-copy"
                  :disabled="!inventoryText.trim()"
                  data-testid="calculator-copy-inventory"
                  @click="copyInventory"
                />
              </div>
              <textarea
                :value="inventoryText || t('CALCULATOR.RESULT.INVENTORY_EMPTY')"
                readonly
                rows="8"
                class="w-full p-4 text-sm border rounded-lg resize-y border-n-weak bg-n-solid-1 text-n-slate-12 focus:outline-none focus:ring-1 focus:ring-n-brand"
                data-testid="calculator-inventory-preview"
              />
            </div>
          </div>
        </section>
      </div>
      <div
        v-else
        class="flex flex-col items-center justify-center min-h-64 p-6 text-center border rounded-2xl border-n-weak bg-n-solid-1"
      >
        <Icon
          icon="i-lucide-lock-keyhole"
          class="mb-3 size-6 text-n-slate-10"
        />
        <p class="text-sm text-n-slate-11">
          {{ t('CALCULATOR.PRIVATE_MESSAGE') }}
        </p>
      </div>

      <Modal
        v-model:show="showVisibilityConfirmModal"
        :show-close-button="false"
        size="medium"
        @close="cancelVisibilityChange"
      >
        <div
          class="flex flex-col gap-5 p-8"
          data-testid="calculator-visibility-confirmation"
        >
          <div class="flex items-start gap-4">
            <div
              class="flex items-center justify-center flex-shrink-0 rounded-2xl size-12"
              :class="
                pendingVisibility
                  ? 'bg-n-brand/10 text-n-brand'
                  : 'bg-n-ruby-4 text-n-ruby-11'
              "
            >
              <Icon
                :icon="
                  pendingVisibility
                    ? 'i-lucide-users-round'
                    : 'i-lucide-lock-keyhole'
                "
                class="size-6"
              />
            </div>
            <div class="flex flex-col gap-1.5 pr-6">
              <h2 class="text-lg font-semibold text-n-slate-12">
                {{
                  t(
                    pendingVisibility
                      ? 'CALCULATOR.SHARING.CONFIRM_SHARED_TITLE'
                      : 'CALCULATOR.SHARING.CONFIRM_PRIVATE_TITLE'
                  )
                }}
              </h2>
              <p class="text-sm leading-5 text-n-slate-11">
                {{
                  t(
                    pendingVisibility
                      ? 'CALCULATOR.SHARING.CONFIRM_SHARED_DESCRIPTION'
                      : 'CALCULATOR.SHARING.CONFIRM_PRIVATE_DESCRIPTION'
                  )
                }}
              </p>
            </div>
          </div>
          <div class="flex justify-end gap-3">
            <Button
              :label="t('CALCULATOR.SHARING.CONFIRM_CANCEL')"
              variant="outline"
              color="slate"
              :disabled="isSavingVisibility"
              @click="cancelVisibilityChange"
            />
            <Button
              :label="
                t(
                  pendingVisibility
                    ? 'CALCULATOR.SHARING.CONFIRM_SHARED'
                    : 'CALCULATOR.SHARING.CONFIRM_PRIVATE'
                )
              "
              :color="pendingVisibility ? 'blue' : 'ruby'"
              :is-loading="isSavingVisibility"
              @click="confirmVisibilityChange"
            />
          </div>
        </div>
      </Modal>
    </template>
  </SettingsLayout>
</template>
