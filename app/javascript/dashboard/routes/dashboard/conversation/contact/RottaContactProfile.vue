<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
/* eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text */
import { computed, reactive, ref, watch } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';

const props = defineProps({
  contact: {
    type: Object,
    default: () => ({}),
  },
});

const PROFILE_KEY = 'rotta_move_profile';

const store = useStore();
const isSaving = ref(false);
const isDirty = ref(false);

const createEmptyProfile = () => ({
  origin: '',
  destination: '',
  move_date: '',
  budget_value: '',
  items: '',
  observations: '',
  helpers_origin: 0,
  helpers_destination: 0,
  assembly_items: '',
  disassembly_items: '',
});

const form = reactive(createEmptyProfile());

const clampHelpers = value => {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed)) return 0;
  return Math.min(99, Math.max(0, parsed));
};

const savedProfile = computed(() => {
  const attributes = props.contact?.custom_attributes || {};
  return attributes[PROFILE_KEY] || attributes.rottaMoveProfile || {};
});

const additionalAttributes = computed(
  () => props.contact?.additional_attributes || {}
);

const whatsappLastSeen = computed(() => {
  const attributes = additionalAttributes.value;
  return (
    attributes.rotta_uazapi_last_seen_at ||
    attributes.rotta_uazapi_last_seen ||
    ''
  );
});

const formatDate = value => {
  if (!value) return 'Não informado';

  const raw = String(value).trim();
  const numeric = /^\d+(\.\d+)?$/.test(raw) ? Number(raw) : Number.NaN;
  const date = Number.isFinite(numeric)
    ? new Date(numeric > 1_000_000_000_000 ? numeric : numeric * 1000)
    : new Date(raw);

  if (Number.isNaN(date.getTime())) return 'Não informado';

  return new Intl.DateTimeFormat('pt-BR', {
    timeZone: 'America/Sao_Paulo',
    dateStyle: 'short',
    timeStyle: 'short',
    hour12: false,
  }).format(date);
};

const loadProfile = () => {
  const profile = savedProfile.value || {};
  Object.assign(form, createEmptyProfile(), profile, {
    helpers_origin: clampHelpers(profile.helpers_origin),
    helpers_destination: clampHelpers(profile.helpers_destination),
  });
  isDirty.value = false;
};

watch(() => [props.contact?.id, savedProfile.value], loadProfile, {
  immediate: true,
  deep: true,
});

const markDirty = () => {
  isDirty.value = true;
};

const changeHelpers = (field, delta) => {
  form[field] = clampHelpers(form[field] + delta);
  markDirty();
};

const normalisedProfile = () => ({
  origin: form.origin.trim(),
  destination: form.destination.trim(),
  move_date: form.move_date,
  budget_value: form.budget_value.trim(),
  items: form.items.trim(),
  observations: form.observations.trim(),
  helpers_origin: clampHelpers(form.helpers_origin),
  helpers_destination: clampHelpers(form.helpers_destination),
  assembly_items: form.assembly_items.trim(),
  disassembly_items: form.disassembly_items.trim(),
});

const save = async () => {
  if (!props.contact?.id || isSaving.value || !isDirty.value) return;

  isSaving.value = true;
  try {
    await store.dispatch('contacts/update', {
      id: props.contact.id,
      customAttributes: {
        [PROFILE_KEY]: normalisedProfile(),
      },
    });
    isDirty.value = false;
    useAlert('Perfil da mudança salvo.');
  } catch (error) {
    useAlert(error.message || 'Não foi possível salvar o perfil da mudança.');
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <section
    class="rotta-contact-profile"
    aria-labelledby="rotta-contact-profile-title"
  >
    <div class="rotta-contact-profile__header">
      <div>
        <h3 id="rotta-contact-profile-title">Perfil da mudança</h3>
        <p>Dados operacionais deste contato.</p>
      </div>
      <span
        class="i-lucide-clipboard-list size-5 text-n-brand"
        aria-hidden="true"
      />
    </div>

    <form
      class="rotta-contact-profile__form"
      @submit.prevent="save"
      @input="markDirty"
    >
      <div class="rotta-contact-profile__grid">
        <label class="rotta-contact-profile__field">
          <span>Origem</span>
          <input
            v-model="form.origin"
            type="text"
            placeholder="Cidade/UF de origem"
            autocomplete="address-level2"
          />
        </label>
        <label class="rotta-contact-profile__field">
          <span>Destino</span>
          <input
            v-model="form.destination"
            type="text"
            placeholder="Cidade/UF de destino"
            autocomplete="address-level2"
          />
        </label>
        <label class="rotta-contact-profile__field">
          <span>Data da mudança</span>
          <input v-model="form.move_date" type="date" />
        </label>
        <label class="rotta-contact-profile__field">
          <span>Valor</span>
          <input
            v-model="form.budget_value"
            type="text"
            inputmode="decimal"
            placeholder="Ex.: R$ 2.500,00"
          />
        </label>
      </div>

      <label class="rotta-contact-profile__field">
        <span>Lista de itens</span>
        <textarea
          v-model="form.items"
          rows="3"
          placeholder="Móveis, caixas e demais itens da mudança"
        />
      </label>

      <section
        class="rotta-contact-profile__services"
        aria-labelledby="rotta-contact-services-title"
      >
        <div class="rotta-contact-profile__section-heading">
          <div>
            <h4 id="rotta-contact-services-title">Serviços</h4>
            <p>Ajudantes e itens de montagem.</p>
          </div>
        </div>

        <div class="rotta-contact-profile__helpers">
          <div class="rotta-contact-profile__helper">
            <span>Ajudantes na origem</span>
            <div class="rotta-contact-profile__stepper">
              <button
                type="button"
                aria-label="Diminuir ajudantes na origem"
                :disabled="form.helpers_origin === 0"
                @click="changeHelpers('helpers_origin', -1)"
              >
                <span class="i-lucide-minus size-4" aria-hidden="true" />
              </button>
              <output aria-live="polite">{{ form.helpers_origin }}</output>
              <button
                type="button"
                aria-label="Aumentar ajudantes na origem"
                @click="changeHelpers('helpers_origin', 1)"
              >
                <span class="i-lucide-plus size-4" aria-hidden="true" />
              </button>
            </div>
          </div>

          <div class="rotta-contact-profile__helper">
            <span>Ajudantes no destino</span>
            <div class="rotta-contact-profile__stepper">
              <button
                type="button"
                aria-label="Diminuir ajudantes no destino"
                :disabled="form.helpers_destination === 0"
                @click="changeHelpers('helpers_destination', -1)"
              >
                <span class="i-lucide-minus size-4" aria-hidden="true" />
              </button>
              <output aria-live="polite">{{ form.helpers_destination }}</output>
              <button
                type="button"
                aria-label="Aumentar ajudantes no destino"
                @click="changeHelpers('helpers_destination', 1)"
              >
                <span class="i-lucide-plus size-4" aria-hidden="true" />
              </button>
            </div>
          </div>
        </div>

        <div class="rotta-contact-profile__grid">
          <label class="rotta-contact-profile__field">
            <span>Montagem</span>
            <textarea
              v-model="form.assembly_items"
              rows="3"
              placeholder="Quais itens serão montados?"
            />
          </label>
          <label class="rotta-contact-profile__field">
            <span>Desmontagem</span>
            <textarea
              v-model="form.disassembly_items"
              rows="3"
              placeholder="Quais itens serão desmontados?"
            />
          </label>
        </div>
      </section>

      <label class="rotta-contact-profile__field">
        <span>Observações</span>
        <textarea
          v-model="form.observations"
          rows="3"
          placeholder="Informações importantes sobre o contato"
        />
      </label>

      <div class="rotta-contact-profile__footer">
        <span v-if="isDirty" class="rotta-contact-profile__dirty">
          Alterações não salvas
        </span>
        <span v-else class="rotta-contact-profile__saved">
          Sincronizado com o contato
        </span>
        <button
          type="submit"
          class="rotta-contact-profile__save"
          :disabled="!isDirty || isSaving || !contact.id"
          :aria-busy="isSaving"
        >
          {{ isSaving ? 'Salvando…' : 'Salvar perfil' }}
        </button>
      </div>
    </form>

    <section
      class="rotta-contact-profile__activity"
      aria-labelledby="rotta-contact-activity-title"
    >
      <div class="rotta-contact-profile__section-heading">
        <div>
          <h4 id="rotta-contact-activity-title">Informações do contato</h4>
          <p>Dados registrados pelo Chatwoot e pela UAZAPI.</p>
        </div>
      </div>
      <dl class="rotta-contact-profile__metadata">
        <div>
          <dt>Primeiro contato registrado</dt>
          <dd>{{ formatDate(contact.created_at) }}</dd>
        </div>
        <div>
          <dt>Última atividade registrada</dt>
          <dd>{{ formatDate(contact.last_activity_at) }}</dd>
        </div>
        <div>
          <dt>Última visualização no WhatsApp</dt>
          <dd>{{ formatDate(whatsappLastSeen) }}</dd>
        </div>
      </dl>
    </section>
  </section>
</template>

<style scoped>
.rotta-contact-profile {
  margin: 0 0.5rem 1rem;
  overflow: hidden;
  @apply bg-n-solid-2 border border-n-weak;
  border-radius: 1rem;
}

.rotta-contact-profile__header,
.rotta-contact-profile__section-heading,
.rotta-contact-profile__footer,
.rotta-contact-profile__helper {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
}

.rotta-contact-profile__header {
  padding: 0.9rem 1rem 0.75rem;
  @apply border-b border-n-weak;
}

.rotta-contact-profile__header h3,
.rotta-contact-profile__section-heading h4 {
  margin: 0;
  @apply text-n-slate-12;
  font-weight: 700;
}

.rotta-contact-profile__header h3 {
  font-size: 0.9rem;
}

.rotta-contact-profile__section-heading h4 {
  font-size: 0.78rem;
}

.rotta-contact-profile__header p,
.rotta-contact-profile__section-heading p {
  margin: 0.25rem 0 0;
  @apply text-n-slate-11;
  font-size: 0.68rem;
  line-height: 1.35;
}

.rotta-contact-profile__form,
.rotta-contact-profile__activity {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  padding: 0.85rem 1rem;
}

.rotta-contact-profile__grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.65rem;
}

.rotta-contact-profile__field {
  display: flex;
  flex-direction: column;
  min-width: 0;
  gap: 0.3rem;
}

.rotta-contact-profile__field > span,
.rotta-contact-profile__helper > span,
.rotta-contact-profile__metadata dt {
  @apply text-n-slate-11;
  font-size: 0.68rem;
  font-weight: 600;
}

.rotta-contact-profile__field input,
.rotta-contact-profile__field textarea {
  width: 100%;
  min-width: 0;
  padding: 0.55rem 0.65rem;
  @apply text-n-slate-12 bg-n-solid-1 border border-n-strong;
  border-radius: 0.55rem;
  font-size: 0.75rem;
  line-height: 1.35;
}

.rotta-contact-profile__field textarea {
  min-height: 4.2rem;
  resize: vertical;
}

.rotta-contact-profile__field input:focus,
.rotta-contact-profile__field textarea:focus {
  @apply border-n-brand;
  outline: 2px solid rgb(var(--brand-7) / 0.25);
  outline-offset: 1px;
}

.rotta-contact-profile__services,
.rotta-contact-profile__activity {
  @apply border-t border-n-weak;
}

.rotta-contact-profile__services {
  display: flex;
  flex-direction: column;
  gap: 0.7rem;
  padding-top: 0.75rem;
}

.rotta-contact-profile__helpers {
  display: flex;
  flex-direction: column;
  gap: 0.55rem;
}

.rotta-contact-profile__helper {
  align-items: center;
  padding: 0.35rem 0;
}

.rotta-contact-profile__stepper {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
}

.rotta-contact-profile__stepper button {
  display: grid;
  place-items: center;
  width: 1.8rem;
  height: 1.8rem;
  @apply text-n-slate-12 bg-n-solid-1 border border-n-strong;
  border-radius: 0.5rem;
  cursor: pointer;
}

.rotta-contact-profile__stepper button:hover:not(:disabled),
.rotta-contact-profile__stepper button:focus-visible {
  @apply border-n-brand text-n-brand;
}

.rotta-contact-profile__stepper button:disabled {
  cursor: not-allowed;
  opacity: 0.45;
}

.rotta-contact-profile__stepper output {
  display: grid;
  min-width: 1.7rem;
  place-items: center;
  @apply text-n-slate-12;
  font-size: 0.78rem;
  font-weight: 700;
}

.rotta-contact-profile__footer {
  align-items: center;
  padding-top: 0.2rem;
}

.rotta-contact-profile__dirty,
.rotta-contact-profile__saved {
  @apply text-n-slate-11;
  font-size: 0.66rem;
}

.rotta-contact-profile__dirty {
  color: #c2410c;
}

.rotta-contact-profile__save {
  padding: 0.5rem 0.75rem;
  @apply text-white bg-n-brand;
  border: 0;
  border-radius: 0.55rem;
  font-size: 0.72rem;
  font-weight: 700;
  cursor: pointer;
}

.rotta-contact-profile__save:hover:not(:disabled),
.rotta-contact-profile__save:focus-visible {
  filter: brightness(0.95);
}

.rotta-contact-profile__save:disabled {
  cursor: not-allowed;
  opacity: 0.5;
}

.rotta-contact-profile__activity {
  gap: 0.65rem;
  padding-top: 0.8rem;
}

.rotta-contact-profile__metadata {
  display: grid;
  grid-template-columns: 1fr;
  gap: 0.55rem;
  margin: 0;
}

.rotta-contact-profile__metadata div {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 0.75rem;
}

.rotta-contact-profile__metadata dd {
  margin: 0;
  @apply text-n-slate-12;
  font-size: 0.7rem;
  text-align: right;
}

@media (max-width: 24rem) {
  .rotta-contact-profile__grid {
    grid-template-columns: 1fr;
  }

  .rotta-contact-profile__metadata div {
    align-items: flex-start;
    flex-direction: column;
    gap: 0.15rem;
  }

  .rotta-contact-profile__metadata dd {
    text-align: left;
  }
}
</style>
