<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import CalculatorAPI from 'dashboard/api/calculator';
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
import { parseInventory } from './calculatorHelpers';

const { t } = useI18n();
const { accountId, currentAccount, updateAccount } = useAccount();
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
const pricing = reactive({
  selectedCardId: 'padrao',
  marginPercent: 35,
  adjustmentPerKm: 0,
  adjustmentStep: 0.25,
  helperUnit: 0,
  assemblerUnit: 0,
  materialsSelected: false,
  materialsTotal: 0,
  specialFee: 0,
  helpers: { origin: 0, destination: 0 },
  assembly: { originDisassembly: 0, destinationAssembly: 0 },
});
const readingText = ref('');
const inventoryText = ref('');
const result = ref(null);
const isCalculating = ref(false);
const calculationError = ref('');
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

const money = value =>
  `R$ ${Number(value || 0).toLocaleString('pt-BR', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;

const selectedPricing = computed(() => result.value?.pricing?.selected || {});

const updatePricingFromResult = data => {
  const extracted = data?.extracted_data || {};
  freight.clientName = extracted.client_name || freight.clientName;
  freight.date = extracted.date || freight.date;
  freight.origin = extracted.origin || freight.origin;
  freight.destination = extracted.destination || freight.destination;
  const parsedServices = extracted.services || {};
  pricing.helpers.origin =
    parsedServices.helpers?.origin ?? pricing.helpers.origin;
  pricing.helpers.destination =
    parsedServices.helpers?.destination ?? pricing.helpers.destination;
  pricing.assembly.originDisassembly =
    parsedServices.assembly?.origin_disassembly ??
    pricing.assembly.originDisassembly;
  pricing.assembly.destinationAssembly =
    parsedServices.assembly?.destination_assembly ??
    pricing.assembly.destinationAssembly;
  const firstInventoryLine = data.inventory?.items
    ?.map(item => `${item.quantity}x ${item.name}`)
    .join('\n');
  if (firstInventoryLine && !inventoryText.value.trim())
    inventoryText.value = firstInventoryLine;
};

watch(
  calculatorSettings,
  settings => {
    isShared.value = !!settings.rotta_calculator_shared;
  },
  { immediate: true }
);

const ensureCalculatorOwnership = async () => {
  const account = currentAccount.value;
  if (
    !account?.id ||
    !Object.prototype.hasOwnProperty.call(account, 'settings')
  )
    return;

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
  pricing.selectedCardId = 'padrao';
  pricing.marginPercent = 35;
  pricing.adjustmentPerKm = 0;
  pricing.adjustmentStep = 0.25;
  pricing.helperUnit = 0;
  pricing.assemblerUnit = 0;
  pricing.materialsSelected = false;
  pricing.materialsTotal = 0;
  pricing.specialFee = 0;
  pricing.helpers.origin = 0;
  pricing.helpers.destination = 0;
  pricing.assembly.originDisassembly = 0;
  pricing.assembly.destinationAssembly = 0;
  result.value = null;
  calculationError.value = '';
  activeResultTab.value = 'proposal';
};

const calculate = async () => {
  if (isCalculating.value) return;

  isCalculating.value = true;
  calculationError.value = '';

  try {
    const { data } = await CalculatorAPI.calculate(accountId.value, {
      reading_text: readingText.value,
      freight: {
        client_name: freight.clientName,
        date: freight.date,
        origin: freight.origin,
        destination: freight.destination,
      },
      services: selectedServices.value,
      inventory: {
        text: inventoryText.value,
        item_count: inventorySummary.value.itemCount,
        volume_m3: inventorySummary.value.volumeM3,
      },
      pricing: {
        selected_card_id: pricing.selectedCardId,
        margin_percent: pricing.marginPercent,
        adjustment_per_km: pricing.adjustmentPerKm,
        adjustment_step: pricing.adjustmentStep,
        helper_unit: pricing.helperUnit,
        assembler_unit: pricing.assemblerUnit,
        materials_selected: pricing.materialsSelected,
        materials_total: pricing.materialsTotal,
        special_fee: pricing.specialFee,
        helpers: pricing.helpers,
        assembly: {
          origin_disassembly: pricing.assembly.originDisassembly,
          destination_assembly: pricing.assembly.destinationAssembly,
        },
      },
    });
    result.value = data;
    updatePricingFromResult(data);
    activeResultTab.value = 'proposal';
  } catch (error) {
    calculationError.value =
      error.response?.data?.error || t('CALCULATOR.ALERTS.CALCULATION_ERROR');
    result.value = null;
    useAlert(calculationError.value);
  } finally {
    isCalculating.value = false;
  }
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

watch(
  currentAccount,
  () => {
    ensureCalculatorOwnership();
  },
  { immediate: true }
);
</script>

<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
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
              :is-loading="isCalculating"
              data-testid="calculator-calculate"
              @click="calculate"
            />
          </div>
          <p
            v-if="calculationError"
            class="text-sm text-n-ruby-11"
            data-testid="calculator-error"
          >
            {{ calculationError }}
          </p>
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
                type="text"
                :placeholder="t('CALCULATOR.FREIGHT.DATE_PLACEHOLDER')"
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
              <div
                class="grid grid-cols-1 gap-3 mt-4 sm:grid-cols-2 lg:grid-cols-4"
              >
                <label class="flex flex-col gap-1 text-xs text-n-slate-11">
                  Ajudantes — origem
                  <input
                    v-model.number="pricing.helpers.origin"
                    type="number"
                    min="0"
                    max="999"
                    class="w-full px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-solid-1 text-n-slate-12"
                  />
                </label>
                <label class="flex flex-col gap-1 text-xs text-n-slate-11">
                  Ajudantes — destino
                  <input
                    v-model.number="pricing.helpers.destination"
                    type="number"
                    min="0"
                    max="999"
                    class="w-full px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-solid-1 text-n-slate-12"
                  />
                </label>
                <label class="flex flex-col gap-1 text-xs text-n-slate-11">
                  Desmontagem — origem
                  <input
                    v-model.number="pricing.assembly.originDisassembly"
                    type="number"
                    min="0"
                    max="999"
                    class="w-full px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-solid-1 text-n-slate-12"
                  />
                </label>
                <label class="flex flex-col gap-1 text-xs text-n-slate-11">
                  Montagem — destino
                  <input
                    v-model.number="pricing.assembly.destinationAssembly"
                    type="number"
                    min="0"
                    max="999"
                    class="w-full px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-solid-1 text-n-slate-12"
                  />
                </label>
                <label class="flex flex-col gap-1 text-xs text-n-slate-11">
                  Valor unitário ajudante
                  <input
                    v-model.number="pricing.helperUnit"
                    type="number"
                    min="0"
                    step="0.01"
                    class="w-full px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-solid-1 text-n-slate-12"
                  />
                </label>
                <label class="flex flex-col gap-1 text-xs text-n-slate-11">
                  Valor unitário montador
                  <input
                    v-model.number="pricing.assemblerUnit"
                    type="number"
                    min="0"
                    step="0.01"
                    class="w-full px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-solid-1 text-n-slate-12"
                  />
                </label>
                <label class="flex flex-col gap-1 text-xs text-n-slate-11">
                  Taxa especial
                  <input
                    v-model.number="pricing.specialFee"
                    type="number"
                    min="0"
                    step="0.01"
                    class="w-full px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-solid-1 text-n-slate-12"
                  />
                </label>
                <label class="flex flex-col gap-1 text-xs text-n-slate-11">
                  Material/embalagem
                  <input
                    v-model.number="pricing.materialsTotal"
                    type="number"
                    min="0"
                    step="0.01"
                    class="w-full px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-solid-1 text-n-slate-12"
                  />
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
                {{
                  result?.ai_status === 'complete'
                    ? t('CALCULATOR.INTEGRATIONS.CONNECTED')
                    : t('CALCULATOR.INTEGRATIONS.READY')
                }}
              </p>
            </div>
            <div class="p-3 border rounded-lg border-n-weak bg-n-solid-1">
              <p class="text-sm font-medium text-n-slate-12">
                {{ t('CALCULATOR.INTEGRATIONS.MAPS_TITLE') }}
              </p>
              <p class="mt-1 text-xs text-n-slate-11">
                {{
                  result?.api_status === 'complete'
                    ? t('CALCULATOR.INTEGRATIONS.CONNECTED')
                    : t('CALCULATOR.INTEGRATIONS.READY')
                }}
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
                {{
                  result.price === null || result.price === undefined
                    ? t('CALCULATOR.RESULT.PRICE_NOT_CONFIGURED')
                    : `R$ ${Number(result.price).toFixed(2)}`
                }}
              </p>
            </div>
            <div class="p-4 rounded-lg bg-n-solid-1">
              <p class="text-xs text-n-slate-11">
                {{ t('CALCULATOR.RESULT.SERVICES') }}
              </p>
              <p class="mt-1 text-sm font-semibold text-n-slate-12">
                {{
                  result.selected_services?.join(', ') ||
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
                {{ t('CALCULATOR.RESULT.ROUTE_PREVIEW_READY') }}
              </p>
              <div class="grid grid-cols-3 gap-2 mt-4">
                <div class="p-3 rounded-lg bg-n-solid-1">
                  <p class="text-xs text-n-slate-11">
                    {{ t('CALCULATOR.RESULT.DISTANCE') }}
                  </p>
                  <p class="mt-1 text-sm font-semibold text-n-slate-12">
                    {{ `${result.distance_km} km` }}
                  </p>
                </div>
                <div class="p-3 rounded-lg bg-n-solid-1">
                  <p class="text-xs text-n-slate-11">
                    {{ t('CALCULATOR.RESULT.DURATION') }}
                  </p>
                  <p class="mt-1 text-sm font-semibold text-n-slate-12">
                    {{ `${result.duration_minutes} min` }}
                  </p>
                </div>
                <div class="p-3 rounded-lg bg-n-solid-1">
                  <p class="text-xs text-n-slate-11">
                    {{ t('CALCULATOR.RESULT.TOLLS') }}
                  </p>
                  <p class="mt-1 text-sm font-semibold text-n-slate-12">
                    {{ t('CALCULATOR.RESULT.TOLL_DISABLED') }}
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
                {{ t('CALCULATOR.INTEGRATIONS.MAPS_BACKEND_ACTIVE') }}
              </p>
            </div>
          </div>
          <section
            class="flex flex-col gap-4 p-4 border rounded-xl border-n-weak bg-n-solid-1"
            data-testid="calculator-pricing"
          >
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div>
                <h3 class="text-sm font-semibold text-n-slate-12">
                  Opções comerciais
                </h3>
                <p class="mt-1 text-xs text-n-slate-11">
                  Seis faixas espelhadas do Hub. O motor aplica margem, piso
                  mínimo de R$ 600 no frete e ajuste manual por quilômetro.
                </p>
              </div>
              <div class="flex flex-wrap gap-2 text-xs text-n-slate-11">
                <label class="flex items-center gap-1"
                  >Margem
                  <input
                    v-model.number="pricing.marginPercent"
                    type="number"
                    min="0"
                    max="95"
                    step="1"
                    class="w-16 px-2 py-1 border rounded border-n-weak bg-n-solid-1"
                  />%
                </label>
                <label class="flex items-center gap-1"
                  >Ajuste/km
                  <input
                    v-model.number="pricing.adjustmentPerKm"
                    type="number"
                    step="0.05"
                    class="w-20 px-2 py-1 border rounded border-n-weak bg-n-solid-1"
                  />
                </label>
                <Button
                  label="Recalcular"
                  size="sm"
                  color="blue"
                  :is-loading="isCalculating"
                  @click="calculate"
                />
              </div>
            </div>
            <div class="grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-3">
              <button
                v-for="card in result.pricing.cards"
                :key="card.id"
                type="button"
                class="flex flex-col gap-2 p-4 text-left border rounded-xl transition-colors"
                :class="
                  card.id === result.pricing.selected_card_id
                    ? 'border-n-brand bg-n-brand/10'
                    : 'border-n-weak bg-n-alpha-1 hover:border-n-brand/50'
                "
                @click="
                  pricing.selectedCardId = card.id;
                  calculate();
                "
              >
                <div class="flex items-center justify-between gap-2">
                  <span class="font-semibold text-n-slate-12">{{
                    card.name
                  }}</span>
                  <span class="text-xs text-n-slate-11">{{
                    card.description
                  }}</span>
                </div>
                <div class="flex items-end justify-between gap-2">
                  <span class="text-lg font-bold text-n-brand">{{
                    money(card.final_price)
                  }}</span>
                  <span class="text-xs text-n-slate-11"
                    >{{ money(card.final_tariff_per_km) }}/km</span
                  >
                </div>
                <div class="grid grid-cols-3 gap-2 text-[11px] text-n-slate-11">
                  <span>Frete {{ money(card.freight_only_price) }}</span>
                  <span>Serviços {{ money(card.services_cost) }}</span>
                  <span>Lucro {{ money(card.profit) }}</span>
                </div>
              </button>
            </div>
            <div class="grid grid-cols-2 gap-3 md:grid-cols-5">
              <div class="p-3 rounded-lg bg-n-alpha-2">
                <p class="text-xs text-n-slate-11">Custo operacional</p>
                <p class="mt-1 text-sm font-semibold text-n-slate-12">
                  {{
                    money(
                      result.pricing.selected.freight_cost +
                        result.pricing.services.total
                    )
                  }}
                </p>
              </div>
              <div class="p-3 rounded-lg bg-n-alpha-2">
                <p class="text-xs text-n-slate-11">Preço final</p>
                <p class="mt-1 text-sm font-semibold text-n-brand">
                  {{ money(selectedPricing.final_price) }}
                </p>
              </div>
              <div class="p-3 rounded-lg bg-n-alpha-2">
                <p class="text-xs text-n-slate-11">Lucro estimado</p>
                <p class="mt-1 text-sm font-semibold text-n-slate-12">
                  {{ money(selectedPricing.profit) }}
                </p>
              </div>
              <div class="p-3 rounded-lg bg-n-alpha-2">
                <p class="text-xs text-n-slate-11">Margem real</p>
                <p class="mt-1 text-sm font-semibold text-n-slate-12">
                  {{ selectedPricing.real_margin_percent }}%
                </p>
              </div>
              <div class="p-3 rounded-lg bg-n-alpha-2">
                <p class="text-xs text-n-slate-11">Caminhão</p>
                <p class="mt-1 text-sm font-semibold text-n-slate-12">
                  {{ result.truck_duration_hours }} h
                </p>
              </div>
            </div>
            <div class="flex flex-wrap gap-3 text-xs text-n-slate-11">
              <span>Pedágios: desativados</span>
              <span>Serviços: {{ money(result.pricing.services.total) }}</span>
              <span>Tempo de rota × 1,25 aplicado ao caminhão</span>
              <span
                v-if="result.inventory.manual_review"
                class="font-semibold text-n-ruby-11"
                >Revisão manual necessária em item(ns)</span
              >
            </div>
          </section>
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
              <div
                v-if="result.inventory?.items?.length"
                class="overflow-x-auto border rounded-lg border-n-weak"
              >
                <table class="w-full text-xs text-left">
                  <thead class="text-n-slate-11 bg-n-alpha-2">
                    <tr>
                      <th class="px-3 py-2">Item</th>
                      <th class="px-3 py-2">Qtd.</th>
                      <th class="px-3 py-2">Montado</th>
                      <th class="px-3 py-2">Desmontado</th>
                      <th class="px-3 py-2">Peso</th>
                      <th class="px-3 py-2">Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr
                      v-for="item in result.inventory.items"
                      :key="`${item.original_line}-${item.name}`"
                      class="border-t border-n-weak text-n-slate-12"
                    >
                      <td class="px-3 py-2">{{ item.name }}</td>
                      <td class="px-3 py-2">{{ item.quantity }}</td>
                      <td class="px-3 py-2">{{ item.mounted_m3 }} m³</td>
                      <td class="px-3 py-2">{{ item.disassembled_m3 }} m³</td>
                      <td class="px-3 py-2">{{ item.weight_kg }} kg</td>
                      <td class="px-3 py-2">
                        {{ item.manual_review ? 'Revisar' : 'Catálogo' }}
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
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
