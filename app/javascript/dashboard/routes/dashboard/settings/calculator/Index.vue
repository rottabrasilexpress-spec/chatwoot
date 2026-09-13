<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import {
  computed,
  nextTick,
  onBeforeUnmount,
  onMounted,
  reactive,
  ref,
  watch,
} from 'vue';
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
import GoogleMapPanel from './GoogleMapPanel.vue';
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
  adjustmentPerKm: 0.25,
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
const routeMode = ref('shared');
const isShared = ref(false);
const showVisibilityConfirmModal = ref(false);
const pendingVisibility = ref(null);
const isSavingVisibility = ref(false);
const activeResultTab = ref('proposal');
const placeAutocompleteListeners = [];

const mapsBackendStatus = computed(() =>
  result.value?.api_status === 'complete'
    ? 'Google Maps visual + motor de rotas do backend ativos'
    : t('CALCULATOR.INTEGRATIONS.READY')
);

const calculatorSettings = computed(() => currentAccount.value?.settings || {});
const canView = computed(() =>
  canViewCalculator({
    shared: calculatorSettings.value.rotta_calculator_shared,
    ownerId: calculatorSettings.value.rotta_calculator_owner_id,
    currentUserId: currentUserId.value,
  })
);

const inventorySummary = computed(() => parseInventory(inventoryText.value));

const selectedServices = computed(() => [
  {
    label: 'Ajudantes',
    selected: pricing.helpers.origin > 0 || pricing.helpers.destination > 0,
  },
  {
    label: 'Desmontagem e montagem',
    selected:
      pricing.assembly.originDisassembly > 0 ||
      pricing.assembly.destinationAssembly > 0,
  },
  { label: 'Material e embalagem', selected: pricing.materialsSelected },
  { label: 'Taxas especiais', selected: pricing.specialFee > 0 },
]);

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
  const pricedServices = data.pricing?.services || {};
  pricing.helpers.origin =
    pricedServices.helpers_origin ??
    parsedServices.helpers?.origin ??
    pricing.helpers.origin;
  pricing.helpers.destination =
    pricedServices.helpers_destination ??
    parsedServices.helpers?.destination ??
    pricing.helpers.destination;
  pricing.assembly.originDisassembly =
    pricedServices.disassembly_origin ??
    parsedServices.assembly?.origin_disassembly ??
    pricing.assembly.originDisassembly;
  pricing.assembly.destinationAssembly =
    pricedServices.assembly_destination ??
    parsedServices.assembly?.destination_assembly ??
    pricing.assembly.destinationAssembly;
  pricing.materialsSelected =
    parsedServices.materials?.selected ?? pricing.materialsSelected;
  pricing.helperUnit = pricedServices.helper_unit ?? pricing.helperUnit;
  pricing.assemblerUnit =
    pricedServices.assembler_unit ?? pricing.assemblerUnit;
  pricing.materialsTotal = pricedServices.materials ?? pricing.materialsTotal;
  pricing.specialFee = pricedServices.special_fee ?? pricing.specialFee;
  pricing.adjustmentPerKm =
    data.pricing?.adjustment_per_km ?? pricing.adjustmentPerKm;
  pricing.adjustmentStep =
    data.pricing?.adjustment_step ?? pricing.adjustmentStep;
  pricing.selectedCardId =
    data.pricing?.selected_card_id ?? pricing.selectedCardId;
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
  pricing.adjustmentPerKm = 0.25;
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
        route_mode: routeMode.value,
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

const adjustPricePerKm = direction => {
  if (isCalculating.value) return;
  const step = Math.max(Number(pricing.adjustmentStep) || 0.25, 0.05);
  const current = Math.max(Number(pricing.adjustmentPerKm) || 0, 0);
  pricing.adjustmentPerKm = Number(
    Math.max(0, current + direction * step).toFixed(2)
  );
  calculate();
};

const selectPricingCard = cardId => {
  if (isCalculating.value || pricing.selectedCardId === cardId) return;
  pricing.selectedCardId = cardId;
  calculate();
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

const setupPlacesAutocomplete = () => {
  const Autocomplete = window.google?.maps?.places?.Autocomplete;
  if (!Autocomplete) return;

  ['origin', 'destination'].forEach(field => {
    const input = document.getElementById(`calculator-${field}`);
    if (!input || input.dataset.rottaPlacesReady === 'true') return;

    const autocomplete = new Autocomplete(input, {
      fields: ['formatted_address', 'geometry', 'name'],
      componentRestrictions: { country: 'br' },
      types: ['geocode'],
    });
    const listener = autocomplete.addListener('place_changed', () => {
      const place = autocomplete.getPlace();
      const value = place.formatted_address || place.name;
      if (value) freight[field] = value;
    });
    input.dataset.rottaPlacesReady = 'true';
    placeAutocompleteListeners.push({ input, listener });
  });
};

const handleGoogleMapsReady = () => {
  nextTick(setupPlacesAutocomplete);
};

watch(
  currentAccount,
  () => {
    ensureCalculatorOwnership();
  },
  { immediate: true }
);

onMounted(() => {
  window.addEventListener('rotta-google-maps-ready', handleGoogleMapsReady);
  nextTick(setupPlacesAutocomplete);
});

onBeforeUnmount(() => {
  window.removeEventListener('rotta-google-maps-ready', handleGoogleMapsReady);
  placeAutocompleteListeners.forEach(({ input, listener }) => {
    listener?.remove?.();
    delete input.dataset.rottaPlacesReady;
  });
  placeAutocompleteListeners.length = 0;
});
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
      <div v-if="canView" class="flex flex-col gap-4 mt-4">
        <section
          class="flex flex-col gap-3 p-4 border rounded-xl border-n-weak bg-n-solid-1 sm:flex-row sm:items-center sm:justify-between"
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
          class="grid grid-cols-1 gap-4 xl:grid-cols-[minmax(0,1.02fr)_minmax(24rem,0.98fr)]"
        >
          <div
            class="flex flex-col gap-3 p-4 border rounded-xl border-n-weak bg-n-solid-1"
          >
            <div class="flex items-start justify-between gap-3">
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
              <span
                class="flex items-center gap-1 px-2 py-1 text-xs rounded-full bg-n-alpha-2 text-n-slate-11"
              >
                <Icon icon="i-lucide-sparkles" class="size-3" /> IA segura
              </span>
            </div>
            <TextArea
              id="calculator-reading"
              v-model="readingText"
              :label="t('CALCULATOR.READING.LABEL')"
              :placeholder="t('CALCULATOR.READING.PLACEHOLDER')"
              custom-text-area-class="min-h-[12rem] xl:min-h-[16rem]"
              min-height="12rem"
              max-height="32rem"
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
          </div>
          <div class="flex flex-col gap-4">
            <GoogleMapPanel
              :origin="freight.origin"
              :destination="freight.destination"
              :route="result"
            />
            <section
              class="flex flex-wrap items-center justify-between gap-3 p-3 border rounded-xl border-n-orange-5 bg-n-orange-1"
              data-testid="calculator-route-mode"
            >
              <div>
                <p class="text-sm font-semibold text-n-slate-12">Modalidade</p>
                <p class="mt-0.5 text-xs text-n-slate-11">
                  Escolha como a rota deve ser apresentada no orçamento.
                </p>
              </div>
              <div
                class="flex items-center gap-1 p-1 border rounded-lg border-n-orange-5 bg-n-solid-1"
              >
                <button
                  type="button"
                  class="px-3 py-2 text-xs font-semibold rounded-md"
                  :class="
                    routeMode === 'shared'
                      ? 'bg-n-orange-9 text-white'
                      : 'text-n-slate-11 hover:bg-n-alpha-2'
                  "
                  @click="routeMode = 'shared'"
                >
                  Aproveitamento logístico
                </button>
                <button
                  type="button"
                  class="px-3 py-2 text-xs font-semibold rounded-md"
                  :class="
                    routeMode === 'exclusive'
                      ? 'bg-n-orange-9 text-white'
                      : 'text-n-slate-11 hover:bg-n-alpha-2'
                  "
                  @click="routeMode = 'exclusive'"
                >
                  Exclusivo
                </button>
              </div>
              <Button
                label="Calcular rota"
                color="blue"
                icon="i-lucide-route"
                :is-loading="isCalculating"
                data-testid="calculator-route-calculate"
                @click="calculate"
              />
            </section>
          </div>
        </section>

        <div
          class="grid grid-cols-1 items-start gap-4 xl:grid-cols-[minmax(20rem,0.9fr)_minmax(0,1.1fr)]"
        >
          <section
            class="flex flex-col gap-3 p-3 border-l-4 rounded-xl border-n-orange-5 bg-n-orange-1/50 xl:col-start-2 xl:row-start-1"
          >
            <div>
              <h2 class="text-base font-semibold text-n-slate-12">
                {{ t('CALCULATOR.FREIGHT.TITLE') }}
              </h2>
              <p class="mt-1 text-sm text-n-slate-11">
                {{ t('CALCULATOR.FREIGHT.DESCRIPTION') }}
              </p>
            </div>
            <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
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
                id="calculator-origin"
                v-model="freight.origin"
                :label="t('CALCULATOR.FREIGHT.ORIGIN')"
                :placeholder="t('CALCULATOR.FREIGHT.ORIGIN_PLACEHOLDER')"
                custom-input-class="bg-n-solid-1/80"
                data-testid="calculator-origin"
              />
              <Input
                id="calculator-destination"
                v-model="freight.destination"
                :label="t('CALCULATOR.FREIGHT.DESTINATION')"
                :placeholder="t('CALCULATOR.FREIGHT.DESTINATION_PLACEHOLDER')"
                custom-input-class="bg-n-solid-1/80"
                data-testid="calculator-destination"
              />
            </div>
          </section>

          <section
            class="flex flex-col gap-3 p-3 border-l-4 rounded-xl border-n-teal-5 bg-n-teal-1/40 xl:col-start-1 xl:row-start-1"
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
              custom-text-area-class="min-h-[8rem] xl:min-h-[10rem]"
              min-height="8rem"
              max-height="24rem"
              resize
              data-testid="calculator-inventory-input"
            />
            <div class="grid grid-cols-2 gap-2">
              <div class="p-2 rounded-lg bg-n-teal-2/60">
                <p class="text-xs text-n-slate-11">
                  {{ t('CALCULATOR.INVENTORY.ITEMS') }}
                </p>
                <p class="mt-1 text-lg font-semibold text-n-slate-12">
                  {{ inventorySummary.itemCount }}
                </p>
              </div>
              <div class="p-2 rounded-lg bg-n-teal-2/60">
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
          <section class="flex flex-col gap-3 xl:col-start-1 xl:row-start-2">
            <div class="flex items-end justify-between gap-3">
              <div>
                <p
                  class="text-xs font-bold tracking-wider uppercase text-n-slate-11"
                >
                  Serviços adicionais
                </p>
                <h2 class="mt-1 text-base font-semibold text-n-slate-12">
                  Quantidades e valores unitários
                </h2>
              </div>
              <span class="text-xs text-n-slate-11"
                >Tudo começa em zero e só entra no preço quando
                preenchido.</span
              >
            </div>
            <div class="grid grid-cols-1 gap-3 md:grid-cols-2">
              <section
                class="flex flex-col gap-2 p-3 border-l-4 border rounded-xl border-n-blue-5 bg-n-solid-1"
              >
                <div class="flex items-center justify-between">
                  <h3 class="font-semibold text-n-slate-12">👥 Ajudantes</h3>
                  <span
                    class="px-2 py-1 text-xs rounded-lg bg-n-blue-3 text-n-blue-11"
                    >{{
                      money(
                        (pricing.helpers.origin + pricing.helpers.destination) *
                          pricing.helperUnit
                      )
                    }}</span
                  >
                </div>
                <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
                  <label class="text-xs text-n-slate-11"
                    >Origem<input
                      v-model.number="pricing.helpers.origin"
                      type="number"
                      min="0"
                      max="999"
                      class="w-full px-3 py-2 mt-1 text-sm border rounded-lg border-n-weak bg-n-solid-1 text-n-slate-12"
                  /></label>
                  <label class="text-xs text-n-slate-11"
                    >Destino<input
                      v-model.number="pricing.helpers.destination"
                      type="number"
                      min="0"
                      max="999"
                      class="w-full px-3 py-2 mt-1 text-sm border rounded-lg border-n-weak bg-n-solid-1 text-n-slate-12"
                  /></label>
                  <label class="text-xs text-n-slate-11"
                    >Valor unit.<input
                      v-model.number="pricing.helperUnit"
                      type="number"
                      min="0"
                      step="0.01"
                      class="w-full px-3 py-2 mt-1 text-sm border rounded-lg border-n-weak bg-n-solid-1 text-n-slate-12"
                  /></label>
                </div>
              </section>
              <section
                class="flex flex-col gap-2 p-3 border-l-4 border rounded-xl border-n-orange-5 bg-n-solid-1"
              >
                <div class="flex items-center justify-between">
                  <h3 class="font-semibold text-n-slate-12">🛠️ Montador</h3>
                  <span
                    class="px-2 py-1 text-xs rounded-lg bg-n-orange-3 text-n-orange-11"
                    >{{
                      money(
                        (pricing.assembly.originDisassembly +
                          pricing.assembly.destinationAssembly) *
                          pricing.assemblerUnit
                      )
                    }}</span
                  >
                </div>
                <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
                  <label class="text-xs text-n-slate-11"
                    >Desmont. origem<input
                      v-model.number="pricing.assembly.originDisassembly"
                      type="number"
                      min="0"
                      max="999"
                      class="w-full px-3 py-2 mt-1 text-sm border rounded-lg border-n-weak bg-n-solid-1 text-n-slate-12"
                  /></label>
                  <label class="text-xs text-n-slate-11"
                    >Montag. destino<input
                      v-model.number="pricing.assembly.destinationAssembly"
                      type="number"
                      min="0"
                      max="999"
                      class="w-full px-3 py-2 mt-1 text-sm border rounded-lg border-n-weak bg-n-solid-1 text-n-slate-12"
                  /></label>
                  <label class="text-xs text-n-slate-11"
                    >Valor unit.<input
                      v-model.number="pricing.assemblerUnit"
                      type="number"
                      min="0"
                      step="0.01"
                      class="w-full px-3 py-2 mt-1 text-sm border rounded-lg border-n-weak bg-n-solid-1 text-n-slate-12"
                  /></label>
                </div>
              </section>
              <section
                class="flex flex-col gap-2 p-3 border-l-4 border rounded-xl border-n-teal-5 bg-n-solid-1"
              >
                <div class="flex items-center justify-between">
                  <h3 class="font-semibold text-n-slate-12">
                    📦 Material e embalagem
                  </h3>
                  <span
                    class="px-2 py-1 text-xs rounded-lg bg-n-teal-3 text-n-teal-11"
                    >{{
                      money(
                        pricing.materialsSelected ? pricing.materialsTotal : 0
                      )
                    }}</span
                  >
                </div>
                <label class="flex items-center gap-2 text-xs text-n-slate-11"
                  ><input
                    v-model="pricing.materialsSelected"
                    type="checkbox"
                    class="rounded border-n-strong text-n-brand focus:ring-n-brand"
                  />
                  Somente material, sem mão de obra</label
                >
                <label class="text-xs text-n-slate-11"
                  >Valor total<input
                    v-model.number="pricing.materialsTotal"
                    type="number"
                    min="0"
                    step="0.01"
                    class="w-full px-3 py-2 mt-1 text-sm border rounded-lg border-n-weak bg-n-solid-1 text-n-slate-12"
                /></label>
              </section>
              <section
                class="flex flex-col gap-2 p-3 border-l-4 border rounded-xl border-n-ruby-5 bg-n-solid-1"
              >
                <div class="flex items-center justify-between">
                  <h3 class="font-semibold text-n-slate-12">
                    🚚 Taxas especiais
                  </h3>
                  <span
                    class="px-2 py-1 text-xs rounded-lg bg-n-ruby-3 text-n-ruby-11"
                    >{{ money(pricing.specialFee) }}</span
                  >
                </div>
                <p class="text-xs text-n-slate-11">
                  Motos, itens pesados, sensíveis ou fora do padrão.
                </p>
                <label class="text-xs text-n-slate-11"
                  >Valor da taxa<input
                    v-model.number="pricing.specialFee"
                    type="number"
                    min="0"
                    step="0.01"
                    class="w-full px-3 py-2 mt-1 text-sm border rounded-lg border-n-weak bg-n-solid-1 text-n-slate-12"
                /></label>
              </section>
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
                    : result?.ai_status === 'degraded'
                      ? t('CALCULATOR.INTEGRATIONS.DEGRADED')
                      : t('CALCULATOR.INTEGRATIONS.READY')
                }}
              </p>
            </div>
            <div class="p-3 border rounded-lg border-n-weak bg-n-solid-1">
              <p class="text-sm font-medium text-n-slate-12">
                {{ t('CALCULATOR.INTEGRATIONS.MAPS_TITLE') }}
              </p>
              <p class="mt-1 text-xs text-n-slate-11">
                {{ mapsBackendStatus }}
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
                {{ mapsBackendStatus }}
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
                  <button
                    type="button"
                    class="px-1.5 py-1 text-sm font-semibold border rounded border-n-weak hover:bg-n-alpha-2"
                    aria-label="Reduzir ajuste por quilômetro"
                    :disabled="isCalculating"
                    @click="adjustPricePerKm(-1)"
                  >
                    −
                  </button>
                  <input
                    v-model.number="pricing.adjustmentPerKm"
                    type="number"
                    step="0.05"
                    class="w-20 px-2 py-1 text-center border rounded border-n-weak bg-n-solid-1"
                  />
                  <button
                    type="button"
                    class="px-1.5 py-1 text-sm font-semibold border rounded border-n-weak hover:bg-n-alpha-2"
                    aria-label="Aumentar ajuste por quilômetro"
                    :disabled="isCalculating"
                    @click="adjustPricePerKm(1)"
                  >
                    +
                  </button>
                </label>
                <label class="flex items-center gap-1"
                  >Passo
                  <input
                    v-model.number="pricing.adjustmentStep"
                    type="number"
                    min="0.05"
                    step="0.05"
                    class="w-16 px-2 py-1 text-center border rounded border-n-weak bg-n-solid-1"
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
                  card.id === pricing.selectedCardId
                    ? 'border-n-brand bg-n-brand/10'
                    : 'border-n-weak bg-n-alpha-1 hover:border-n-brand/50'
                "
                :aria-pressed="card.id === pricing.selectedCardId"
                :disabled="isCalculating"
                @click="selectPricingCard(card.id)"
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
                rows="14"
                class="w-full min-h-[20rem] p-4 text-sm border rounded-lg resize-y border-n-weak bg-n-solid-1 text-n-slate-12 focus:outline-none focus:ring-1 focus:ring-n-brand"
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
                rows="14"
                class="w-full min-h-[20rem] p-4 text-sm border rounded-lg resize-y border-n-weak bg-n-solid-1 text-n-slate-12 focus:outline-none focus:ring-1 focus:ring-n-brand"
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
