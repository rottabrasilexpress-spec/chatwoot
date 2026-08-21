<script setup>
import {
  ref,
  unref,
  provide,
  computed,
  watch,
  onMounted,
  onBeforeUnmount,
} from 'vue';
import { useStore } from 'vuex';
import { useRoute, useRouter } from 'vue-router';
import {
  useMapGetter,
  useFunctionGetter,
} from 'dashboard/composables/store.js';

import ChatListHeader from './ChatListHeader.vue';
import ConversationList from './ConversationList.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import ConversationFilter from 'next/filter/ConversationFilter.vue';
import SaveCustomView from 'next/filter/SaveCustomView.vue';
import DeleteCustomViews from 'dashboard/routes/dashboard/customviews/DeleteCustomViews.vue';
import ConversationBulkActions from './widgets/conversation/conversationBulkActions/Index.vue';
import TeleportWithDirection from 'dashboard/components-next/TeleportWithDirection.vue';
import ConversationResolveAttributesModal from 'dashboard/components-next/ConversationWorkflow/ConversationResolveAttributesModal.vue';

import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAlert } from 'dashboard/composables';
import { useBulkActions } from 'dashboard/composables/chatlist/useBulkActions';
import { useFilter } from 'shared/composables/useFilter';
import { useTrack } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import {
  useCamelCase,
  useSnakeCase,
} from 'dashboard/composables/useTransformKeys';
import { useEmitter } from 'dashboard/composables/emitter';
import { useConversationRequiredAttributes } from 'dashboard/composables/useConversationRequiredAttributes';

import wootConstants from 'dashboard/constants/globals';
import advancedFilterOptions from './widgets/conversation/advancedFilterItems';
import filterQueryGenerator from '../helper/filterQueryGenerator.js';
import languages from 'dashboard/components/widgets/conversation/advancedFilterItems/languages';
import countries from 'shared/constants/countries';
import { generateValuesForEditCustomViews } from 'dashboard/helper/customViewsHelper';
import { conversationListPageURL } from '../helper/URLHelper';
import ConversationApi from 'dashboard/api/inbox/conversation';
import {
  isOnMentionsView,
  isOnParticipatingView,
  isOnUnattendedView,
} from '../store/modules/conversations/helpers/actionHelpers';
import { matchesFilters } from '../store/modules/conversations/helpers/filterHelpers';
import { CONVERSATION_EVENTS } from '../helper/AnalyticsHelper/events';

const props = defineProps({
  conversationInbox: { type: [String, Number], default: 0 },
  teamId: { type: [String, Number], default: 0 },
  label: { type: String, default: '' },
  conversationType: { type: String, default: '' },
  conversationStatus: { type: String, default: '' },
  foldersId: { type: [String, Number], default: 0 },
  showConversationList: { default: true, type: Boolean },
  isOnExpandedLayout: { default: false, type: Boolean },
});

const emit = defineEmits(['conversationLoad']);
const { uiSettings } = useUISettings();
const { t } = useI18n();
const router = useRouter();
const route = useRoute();
const store = useStore();

const resolveAttributesModalRef = ref(null);

const activeAssigneeTab = ref(wootConstants.ASSIGNEE_TYPE.ALL);
const activeStatus = ref(
  props.conversationStatus || wootConstants.STATUS_TYPE.OPEN
);
const activeSortBy = ref(wootConstants.SORT_BY_TYPE.LAST_ACTIVITY_AT_DESC);
const showAdvancedFilters = ref(false);
// chatsOnView is to store the chats that are currently visible on the screen,
// which mirrors the conversationList.
const chatsOnView = ref([]);
const foldersQuery = ref({});
const showAddFoldersModal = ref(false);
const showDeleteFoldersModal = ref(false);
const appliedFilter = ref([]);
const conversationListWidth = ref(340);
const isResizingConversationList = ref(false);
const resizeStartX = ref(0);
const resizeStartWidth = ref(340);
const resizeConversationsLabel = 'Redimensionar lista de conversas';
const noSearchResultsLabel = 'Nenhuma conversa encontrada.';
const conversationSearchQuery = ref('');
const isMarkingAllAsRead = ref(false);
const remoteSearchResults = ref(null);
const isSearchingConversations = ref(false);
let conversationSearchTimer = null;
const advancedFilterTypes = ref(
  advancedFilterOptions.map(filter => ({
    ...filter,
    attributeName: t(`FILTER.ATTRIBUTES.${filter.attributeI18nKey}`),
  }))
);

const currentUser = useMapGetter('getCurrentUser');
const chatLists = useMapGetter('getFilteredConversations');
const mineChatsList = useMapGetter('getMineChats');
const allChatList = useMapGetter('getAllStatusChats');
const unAssignedChatsList = useMapGetter('getUnAssignedChats');
const participatingChatsList = useMapGetter('getParticipatingChats');
const chatListLoading = useMapGetter('getChatListLoadingStatus');
const activeInbox = useMapGetter('getSelectedInbox');
const conversationStats = useMapGetter('conversationStats/getStats');
const appliedFilters = useMapGetter('getAppliedConversationFiltersV2');
const folders = useMapGetter('customViews/getConversationCustomViews');
const agentList = useMapGetter('agents/getAgents');
const teamsList = useMapGetter('teams/getTeams');
const inboxesList = useMapGetter('inboxes/getInboxes');
const campaigns = useMapGetter('campaigns/getAllCampaigns');
const labels = useMapGetter('labels/getLabels');
// We can't useFunctionGetter here since it needs to be called on setup?
const getTeamFn = useMapGetter('teams/getTeam');
const getConversationById = useMapGetter('getConversationById');

const {
  selectedConversations,
  selectConversation,
  deSelectConversation,
  selectAllConversations,
  resetBulkActions,
  isConversationSelected,
  onAssignLabels,
  onRemoveLabels,
} = useBulkActions();

const {
  initializeStatusAndAssigneeFilterToModal,
  initializeInboxTeamAndLabelFilterToModal,
} = useFilter({
  filteri18nKey: 'FILTER',
  attributeModel: 'conversation_attribute',
});

const { checkMissingAttributes } = useConversationRequiredAttributes();

// computed

const hasAppliedFilters = computed(() => {
  return appliedFilters.value.length !== 0;
});

const activeFolder = computed(() => {
  if (props.foldersId) {
    const activeView = folders.value.filter(
      view => view.id === Number(props.foldersId)
    );
    const [firstValue] = activeView;
    return firstValue;
  }
  return undefined;
});

const getContact = useMapGetter('contacts/getContact');
const folderContactId = useMapGetter('customViews/getActiveFolderContactId');

const activeFolderName = computed(() => {
  return activeFolder.value?.name;
});

const hasActiveFolders = computed(() => {
  return Boolean(activeFolder.value && props.foldersId !== 0);
});

const hasAppliedFiltersOrActiveFolders = computed(() => {
  return hasAppliedFilters.value || hasActiveFolders.value;
});

const currentUserDetails = computed(() => {
  const { id, name } = currentUser.value;
  return { id, name };
});

const showAssigneeInConversationCard = computed(() => {
  return (
    hasAppliedFiltersOrActiveFolders.value ||
    activeAssigneeTab.value === wootConstants.ASSIGNEE_TYPE.ALL
  );
});

const currentPageFilterKey = computed(() => {
  return hasAppliedFiltersOrActiveFolders.value
    ? 'appliedFilters'
    : activeAssigneeTab.value;
});

const inbox = useFunctionGetter('inboxes/getInbox', activeInbox);
const currentPage = useFunctionGetter(
  'conversationPage/getCurrentPageFilter',
  activeAssigneeTab
);
const currentFiltersPage = useFunctionGetter(
  'conversationPage/getCurrentPageFilter',
  currentPageFilterKey
);
const hasCurrentPageEndReached = useFunctionGetter(
  'conversationPage/getHasEndReached',
  currentPageFilterKey
);

const conversationCustomAttributes = useFunctionGetter(
  'attributes/getAttributesByModel',
  'conversation_attribute'
);

const activeAssigneeTabCount = computed(() => {
  return conversationStats.value.all_count || 0;
});

const labelRouteKey = value =>
  String(value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLocaleLowerCase('pt-BR')
    .replace(/[^a-z0-9]+/g, '-');

const activeLabelTitle = computed(() => {
  if (!props.label) return '';

  const requestedKey = labelRouteKey(props.label);
  const matchingLabel = labels.value.find(
    label => labelRouteKey(label.title) === requestedKey
  );

  return matchingLabel?.title || props.label;
});

const conversationListPagination = computed(() => {
  const conversationsPerPage = 25;
  const hasChatsOnView =
    chatsOnView.value &&
    Array.isArray(chatsOnView.value) &&
    !chatsOnView.value.length;
  const isNoFiltersOrFoldersAndChatListNotEmpty =
    !hasAppliedFiltersOrActiveFolders.value && hasChatsOnView;
  const isUnderPerPage =
    chatsOnView.value.length < conversationsPerPage &&
    activeAssigneeTabCount.value < conversationsPerPage &&
    activeAssigneeTabCount.value > chatsOnView.value.length;

  if (isNoFiltersOrFoldersAndChatListNotEmpty && isUnderPerPage) {
    return 1;
  }

  return currentPage.value + 1;
});

const isSpecialConversationView = computed(() =>
  [
    wootConstants.CONVERSATION_TYPE.AWAITING_REPLY,
    wootConstants.CONVERSATION_TYPE.PRIORITY,
  ].includes(props.conversationType)
);

const conversationFilters = computed(() => {
  return {
    inboxId: props.conversationInbox ? props.conversationInbox : undefined,
    assigneeType: isSpecialConversationView.value
      ? wootConstants.ASSIGNEE_TYPE.ALL
      : activeAssigneeTab.value,
    // A label view must include resolved conversations as well. This is what
    // makes the native "arquivado" label find conversations in Arquivados.
    status: props.label ? wootConstants.STATUS_TYPE.ALL : activeStatus.value,
    sortBy: activeSortBy.value,
    page: conversationListPagination.value,
    labels: activeLabelTitle.value ? [activeLabelTitle.value] : undefined,
    teamId: props.teamId || undefined,
    conversationType: props.conversationType || undefined,
  };
});

const activeTeam = computed(() => {
  if (props.teamId) {
    return getTeamFn.value(props.teamId);
  }
  return {};
});

const pageTitle = computed(() => {
  if (hasAppliedFilters.value) {
    return t('CHAT_LIST.TAB_HEADING');
  }
  if (inbox.value.name) {
    return inbox.value.name;
  }
  if (activeTeam.value.name) {
    return activeTeam.value.name;
  }
  if (props.conversationType === wootConstants.CONVERSATION_TYPE.ARCHIVED) {
    return 'Arquivados';
  }
  if (props.label) {
    return `#${props.label}`;
  }
  if (props.conversationType === wootConstants.CONVERSATION_TYPE.MENTION) {
    return t('CHAT_LIST.MENTION_HEADING');
  }
  if (
    props.conversationType === wootConstants.CONVERSATION_TYPE.PARTICIPATING
  ) {
    return t('CONVERSATION_PARTICIPANTS.SIDEBAR_MENU_TITLE');
  }
  if (props.conversationType === wootConstants.CONVERSATION_TYPE.UNATTENDED) {
    return t('CHAT_LIST.UNATTENDED_HEADING');
  }
  if (
    props.conversationType === wootConstants.CONVERSATION_TYPE.AWAITING_REPLY
  ) {
    return 'Não lidas';
  }
  if (props.conversationType === wootConstants.CONVERSATION_TYPE.PRIORITY) {
    return 'ACOMPANHE';
  }
  if (hasActiveFolders.value) {
    return activeFolder.value.name;
  }
  return t('CHAT_LIST.TAB_HEADING');
});

function filterByAssigneeTab(conversations) {
  if (activeAssigneeTab.value === wootConstants.ASSIGNEE_TYPE.ME) {
    return conversations.filter(
      c => c.meta?.assignee?.id === currentUser.value?.id
    );
  }
  if (activeAssigneeTab.value === wootConstants.ASSIGNEE_TYPE.UNASSIGNED) {
    return conversations.filter(c => !c.meta?.assignee);
  }
  return [...conversations];
}

function sortByUnreadStatus(conversations) {
  return [...conversations].sort((a, b) => {
    const unreadCountDiff = (b.unread_count || 0) - (a.unread_count || 0);
    if (unreadCountDiff !== 0) return unreadCountDiff;

    return (b.last_activity_at || 0) - (a.last_activity_at || 0);
  });
}

function isPinnedConversation(conversation) {
  const value = conversation?.custom_attributes?.rotta_pinned;
  return value === true || value === 1 || value === 'true' || value === '1';
}

function toActivityTime(value) {
  if (value === null || value === undefined || value === '') return 0;

  const rawValue = String(value).trim();
  if (/^\d+(\.\d+)?$/.test(rawValue)) {
    const numericValue = Number(rawValue);
    return numericValue < 1e12 ? numericValue * 1000 : numericValue;
  }

  const parsedValue = Date.parse(rawValue);
  return Number.isNaN(parsedValue) ? 0 : parsedValue;
}

function sortByRottaOrder(conversations) {
  return [...conversations].sort((a, b) => {
    const pinnedDifference =
      Number(isPinnedConversation(b)) - Number(isPinnedConversation(a));
    if (pinnedDifference !== 0) return pinnedDifference;

    const activityOf = conversation => {
      const activityValues = [
        conversation.last_non_activity_message?.created_at,
        conversation.timestamp,
        conversation.last_activity_at,
        conversation.created_at,
        conversation.updated_at,
      ];
      return activityValues.map(toActivityTime).find(Boolean) || 0;
    };

    return activityOf(b) - activityOf(a);
  });
}

const conversationList = computed(() => {
  let localConversationList = [];

  if (!hasAppliedFiltersOrActiveFolders.value) {
    const filters = conversationFilters.value;
    if (isSpecialConversationView.value) {
      localConversationList = [...allChatList.value(filters)];
    } else if (
      props.conversationType === wootConstants.CONVERSATION_TYPE.PARTICIPATING
    ) {
      localConversationList = filterByAssigneeTab(
        participatingChatsList.value(filters)
      );
    } else if (activeAssigneeTab.value === 'me') {
      localConversationList = [...mineChatsList.value(filters)];
    } else if (activeAssigneeTab.value === 'unassigned') {
      localConversationList = [...unAssignedChatsList.value(filters)];
    } else {
      localConversationList = [...allChatList.value(filters)];
    }
  } else {
    localConversationList = [...chatLists.value];
  }

  if (activeFolder.value) {
    const { payload } = activeFolder.value.query;
    localConversationList = localConversationList.filter(conversation => {
      return matchesFilters(conversation, payload);
    });
  }

  if (
    !hasAppliedFiltersOrActiveFolders.value &&
    activeSortBy.value === wootConstants.SORT_BY_TYPE.UNREAD
  ) {
    localConversationList = sortByUnreadStatus(localConversationList);
  }

  return sortByRottaOrder(localConversationList);
});

const searchableConversationText = conversation => {
  const labelsText = (conversation.labels || [])
    .map(label => (typeof label === 'string' ? label : label?.title))
    .filter(Boolean);

  return [
    conversation.id,
    conversation.display_id,
    conversation.meta?.sender?.name,
    conversation.meta?.sender?.phone_number,
    conversation.meta?.sender?.email,
    conversation.contact?.name,
    conversation.contact?.phone_number,
    conversation.last_non_activity_message?.content,
    ...labelsText,
  ]
    .filter(Boolean)
    .join(' ')
    .toLocaleLowerCase('pt-BR');
};

const filteredConversationList = computed(() => {
  const query = conversationSearchQuery.value.trim().toLocaleLowerCase('pt-BR');
  if (!query) return conversationList.value;

  const sourceList = remoteSearchResults.value || conversationList.value;

  return sourceList.filter(conversation =>
    searchableConversationText(conversation).includes(query)
  );
});

const showRottaConversationShortcuts = computed(() => {
  return (
    !hasAppliedFiltersOrActiveFolders.value &&
    !props.conversationInbox &&
    !props.teamId &&
    !props.label &&
    !props.foldersId &&
    !props.conversationType
  );
});

const showEndOfListMessage = computed(() => {
  return !!(
    conversationList.value.length &&
    hasCurrentPageEndReached.value &&
    !chatListLoading.value &&
    !conversationSearchQuery.value.trim()
  );
});

const allConversationsSelected = computed(() => {
  return (
    conversationList.value.length === selectedConversations.value.length &&
    conversationList.value.every(el =>
      selectedConversations.value.includes(el.id)
    )
  );
});

// ---------------------- Methods -----------------------
function setFiltersFromUISettings() {
  const { conversations_filter_by: filterBy = {} } = uiSettings.value;
  const { status, order_by: orderBy } = filterBy;
  activeStatus.value =
    props.conversationStatus || status || wootConstants.STATUS_TYPE.OPEN;
  activeSortBy.value = Object.values(wootConstants.SORT_BY_TYPE).includes(
    orderBy
  )
    ? orderBy
    : wootConstants.SORT_BY_TYPE.LAST_ACTIVITY_AT_DESC;
}

function emitConversationLoaded() {
  emit('conversationLoad');
}

function fetchFilteredConversations(payload) {
  payload = useSnakeCase(payload);
  let page = currentFiltersPage.value + 1;
  store
    .dispatch('fetchFilteredConversations', {
      queryData: filterQueryGenerator(payload),
      page,
    })
    .catch(() => useAlert(t('CHAT_LIST.FETCH_ERROR')))
    // emit even on failure so a deep-linked conversation still loads via
    // fetchConversationIfUnavailable
    .finally(emitConversationLoaded);

  showAdvancedFilters.value = false;
}

function fetchSavedFilteredConversations(payload) {
  payload = useSnakeCase(payload);
  let page = currentFiltersPage.value + 1;
  store
    .dispatch('fetchFilteredConversations', {
      queryData: payload,
      page,
    })
    .catch(() => useAlert(t('CHAT_LIST.FETCH_ERROR')))
    .finally(emitConversationLoaded);
}

function onApplyFilter(payload) {
  payload = useSnakeCase(payload);
  resetBulkActions();
  foldersQuery.value = filterQueryGenerator(payload);
  store.dispatch('conversationPage/reset');
  store.dispatch('emptyAllConversations');
  fetchFilteredConversations(payload);
}

function closeAdvanceFiltersModal() {
  showAdvancedFilters.value = false;
  appliedFilter.value = [];
}

function onUpdateSavedFilter(payload, folderName) {
  const transformedPayload = useSnakeCase(payload);
  const payloadData = {
    ...unref(activeFolder),
    name: unref(folderName),
    query: filterQueryGenerator(transformedPayload),
  };
  store.dispatch('customViews/update', payloadData);
  closeAdvanceFiltersModal();
}

function onClickOpenAddFoldersModal() {
  showAddFoldersModal.value = true;
}

function onCloseAddFoldersModal() {
  showAddFoldersModal.value = false;
}

function onClickOpenDeleteFoldersModal() {
  showDeleteFoldersModal.value = true;
}

function onCloseDeleteFoldersModal() {
  showDeleteFoldersModal.value = false;
}

function setParamsForEditFolderModal() {
  // Here we are setting the params for edit folder modal to show the existing values.

  // For agent, team, inboxes,and campaigns we get only the id's from the query.
  // So we are mapping the id's to the actual values.

  // For labels we get the name of the label from the query.
  // If we delete the label from the label list then we will not be able to show the label name.

  // For custom attributes we get only attribute key.
  // So we are mapping it to find the input type of the attribute to show in the edit folder modal.
  return {
    agents: agentList.value,
    teams: teamsList.value,
    inboxes: inboxesList.value,
    labels: labels.value,
    campaigns: campaigns.value,
    contacts: [getContact.value(folderContactId.value)],
    languages: languages,
    countries: countries,
    priority: [
      { id: 'low', name: t('CONVERSATION.PRIORITY.OPTIONS.LOW') },
      { id: 'medium', name: t('CONVERSATION.PRIORITY.OPTIONS.MEDIUM') },
      { id: 'high', name: t('CONVERSATION.PRIORITY.OPTIONS.HIGH') },
      { id: 'urgent', name: t('CONVERSATION.PRIORITY.OPTIONS.URGENT') },
    ],
    filterTypes: advancedFilterTypes.value,
    allCustomAttributes: conversationCustomAttributes.value,
  };
}

function initializeExistingFilterToModal() {
  const statusFilter = initializeStatusAndAssigneeFilterToModal(
    activeStatus.value,
    currentUserDetails.value,
    activeAssigneeTab.value
  );
  // TODO: Remove the usage of useCamelCase after migrating useFilter to camelcase
  if (statusFilter) {
    appliedFilter.value = [...appliedFilter.value, useCamelCase(statusFilter)];
  }

  // TODO: Remove the usage of useCamelCase after migrating useFilter to camelcase
  const otherFilters = initializeInboxTeamAndLabelFilterToModal(
    props.conversationInbox,
    inbox.value,
    props.teamId,
    activeTeam.value,
    props.label
  ).map(useCamelCase);

  appliedFilter.value = [...appliedFilter.value, ...otherFilters];
}

function initializeFolderToFilterModal(newActiveFolder) {
  // Here we are setting the params for edit folder modal.
  //  To show the existing values. when we click on edit folder button.

  // Here we get the query from the active folder.
  // And we are mapping the query to the actual values.
  // To show in the edit folder modal by the help of generateValuesForEditCustomViews helper.
  const query = unref(newActiveFolder)?.query?.payload;
  if (!Array.isArray(query)) return;

  const newFilters = query.map(filter => {
    const transformed = useCamelCase(filter);
    const values = Array.isArray(transformed.values)
      ? generateValuesForEditCustomViews(
          useSnakeCase(filter),
          setParamsForEditFolderModal()
        )
      : [];

    return {
      attributeKey: transformed.attributeKey,
      attributeModel: transformed.attributeModel,
      customAttributeType: transformed.customAttributeType,
      filterOperator: transformed.filterOperator,
      queryOperator: transformed.queryOperator ?? 'and',
      values,
    };
  });

  appliedFilter.value = [...appliedFilter.value, ...newFilters];
}

function initalizeAppliedFiltersToModal() {
  appliedFilter.value = [...appliedFilters.value];
}

function onToggleAdvanceFiltersModal() {
  if (showAdvancedFilters.value === true) {
    closeAdvanceFiltersModal();
    return;
  }

  if (!hasAppliedFilters.value && !hasActiveFolders.value) {
    initializeExistingFilterToModal();
  }
  if (hasActiveFolders.value) {
    initializeFolderToFilterModal(activeFolder.value);
  }
  if (hasAppliedFilters.value) {
    initalizeAppliedFiltersToModal();
  }

  showAdvancedFilters.value = true;
}

function fetchConversations() {
  store.dispatch('updateChatListFilters', conversationFilters.value);
  store.dispatch('fetchAllConversations').then(emitConversationLoaded);
}

function resetAndFetchData() {
  appliedFilter.value = [];
  resetBulkActions();
  store.dispatch('conversationPage/reset');
  store.dispatch('emptyAllConversations');
  store.dispatch('clearConversationFilters');
  if (hasActiveFolders.value) {
    const payload = activeFolder.value.query;
    fetchSavedFilteredConversations(payload);
  }
  if (props.foldersId) {
    return;
  }
  fetchConversations();
}

function loadMoreConversations() {
  if (hasCurrentPageEndReached.value || chatListLoading.value) {
    return;
  }

  if (!hasAppliedFiltersOrActiveFolders.value) {
    fetchConversations();
  } else if (hasActiveFolders.value) {
    const payload = activeFolder.value.query;
    fetchSavedFilteredConversations(payload);
  } else if (hasAppliedFilters.value) {
    fetchFilteredConversations(appliedFilters.value);
  }
}

function onBasicFilterChange(value, type) {
  if (type === 'status') {
    if (props.conversationStatus) return;
    activeStatus.value = value;
  } else {
    activeSortBy.value = value;
  }
  resetAndFetchData();
}

function openLastSavedItemInFolder() {
  const lastItemOfFolder = folders.value[folders.value.length - 1];
  const lastItemId = lastItemOfFolder.id;
  router.push({
    name: 'folder_conversations',
    params: { id: lastItemId },
  });
}

function openLastItemAfterDeleteInFolder() {
  if (folders.value.length > 0) {
    openLastSavedItemInFolder();
  } else {
    router.push({ name: 'home' });
    fetchConversations();
  }
}

function redirectToConversationList() {
  const {
    params: { accountId, inbox_id: inboxId, label, teamId },
    name,
  } = route;

  let conversationType = '';
  if (isOnMentionsView({ route: { name } })) {
    conversationType = wootConstants.CONVERSATION_TYPE.MENTION;
  } else if (isOnParticipatingView({ route: { name } })) {
    conversationType = wootConstants.CONVERSATION_TYPE.PARTICIPATING;
  } else if (isOnUnattendedView({ route: { name } })) {
    conversationType = wootConstants.CONVERSATION_TYPE.UNATTENDED;
  } else if (
    name === 'conversation_awaiting_reply' ||
    name === 'conversation_through_awaiting_reply'
  ) {
    conversationType = wootConstants.CONVERSATION_TYPE.AWAITING_REPLY;
  } else if (
    name === 'conversation_priority' ||
    name === 'conversation_through_priority'
  ) {
    conversationType = wootConstants.CONVERSATION_TYPE.PRIORITY;
  } else if (
    name === 'archived_conversations' ||
    name === 'archived_conversation'
  ) {
    conversationType = wootConstants.CONVERSATION_TYPE.ARCHIVED;
  }
  router.push(
    conversationListPageURL({
      accountId,
      conversationType: conversationType,
      customViewId: props.foldersId,
      inboxId,
      label,
      teamId,
    })
  );
}

async function assignPriority(priority, conversationId = null) {
  store.dispatch('setCurrentChatPriority', {
    priority,
    conversationId,
  });
  store.dispatch('assignPriority', { conversationId, priority }).then(() => {
    useTrack(CONVERSATION_EVENTS.CHANGE_PRIORITY, {
      newValue: priority,
      from: 'Context menu',
    });
    useAlert(
      t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.SUCCESSFUL', {
        priority,
        conversationId,
      })
    );
  });
}

async function togglePinned(conversationId) {
  const conversation = getConversationById.value(conversationId);
  const pinned = isPinnedConversation(conversation);
  try {
    await store.dispatch('updateCustomAttributes', {
      conversationId,
      customAttributes: { rotta_pinned: !pinned },
    });
    // The conversation list is re-sorted as soon as the store receives the
    // update. Keep the message consistent with the state the user changed,
    // instead of reading the already-reactive value after the dispatch.
    useAlert(pinned ? 'Conversa desafixada.' : 'Conversa fixada.');
  } catch (error) {
    useAlert(
      'Não foi possível atualizar a fixação da conversa. Tente novamente.'
    );
  }
}

async function markAsUnread(conversationId) {
  try {
    await store.dispatch('markMessagesUnread', {
      id: conversationId,
    });
    redirectToConversationList();
  } catch (error) {
    // Ignore error
  }
}
async function markAsRead(conversationId) {
  try {
    await store.dispatch('markMessagesRead', {
      id: conversationId,
    });
  } catch (error) {
    // Ignore error
  }
}

async function markAllVisibleAsRead() {
  const unreadConversationIds = conversationList.value
    .filter(conversation => Number(conversation.unread_count) > 0)
    .map(conversation => conversation.id);

  if (!unreadConversationIds.length) {
    useAlert('Não há conversas não lidas nesta lista.');
    return;
  }

  isMarkingAllAsRead.value = true;
  try {
    await Promise.all(unreadConversationIds.map(id => markAsRead(id)));
    useAlert(
      `${unreadConversationIds.length} conversa(s) marcada(s) como lida(s).`
    );
  } finally {
    isMarkingAllAsRead.value = false;
  }
}

async function searchConversationsRemotely(query) {
  const normalizedQuery = query.trim();
  if (normalizedQuery.length < 2) {
    remoteSearchResults.value = null;
    isSearchingConversations.value = false;
    return;
  }

  isSearchingConversations.value = true;
  try {
    const { data } = await ConversationApi.get({
      ...conversationFilters.value,
      page: 1,
      q: normalizedQuery,
    });
    remoteSearchResults.value = data.data?.payload || [];
  } catch (error) {
    remoteSearchResults.value = [];
    useAlert('Não foi possível pesquisar as conversas. Tente novamente.');
  } finally {
    isSearchingConversations.value = false;
  }
}

function scheduleConversationSearch(query) {
  clearTimeout(conversationSearchTimer);
  conversationSearchTimer = setTimeout(
    () => searchConversationsRemotely(query),
    300
  );
}

async function onAssignTeam(team, conversationId = null) {
  try {
    await store.dispatch('assignTeam', {
      conversationId,
      teamId: team.id,
    });
    useAlert(
      t('CONVERSATION.CARD_CONTEXT_MENU.API.TEAM_ASSIGNMENT.SUCCESFUL', {
        team: team.name,
        conversationId,
      })
    );
  } catch (error) {
    useAlert(t('CONVERSATION.CARD_CONTEXT_MENU.API.TEAM_ASSIGNMENT.FAILED'));
  }
}

function toggleConversationStatus(
  conversationId,
  status,
  snoozedUntil,
  customAttributes = null
) {
  const payload = {
    conversationId,
    status,
    snoozedUntil,
  };

  if (customAttributes) {
    payload.customAttributes = customAttributes;
  }

  store.dispatch('toggleStatus', payload).then(() => {
    useAlert(t('CONVERSATION.CHANGE_STATUS'));
  });
}

function handleResolveConversation(conversationId, status, snoozedUntil) {
  if (status !== wootConstants.STATUS_TYPE.RESOLVED) {
    toggleConversationStatus(conversationId, status, snoozedUntil);
    return;
  }

  // Check for required attributes before resolving
  const conversation = getConversationById.value(conversationId);
  const currentCustomAttributes = conversation?.custom_attributes || {};
  const { hasMissing, missing } = checkMissingAttributes(
    currentCustomAttributes
  );

  if (hasMissing) {
    // Pass conversation context through the modal's API
    const conversationContext = {
      id: conversationId,
      snoozedUntil,
    };
    resolveAttributesModalRef.value?.open(
      missing,
      currentCustomAttributes,
      conversationContext
    );
  } else {
    toggleConversationStatus(conversationId, status, snoozedUntil);
  }
}

function handleResolveWithAttributes({ attributes, context }) {
  if (context) {
    const existingConversation = getConversationById.value(context.id);
    const currentCustomAttributes =
      existingConversation?.custom_attributes || {};
    const mergedAttributes = { ...currentCustomAttributes, ...attributes };

    toggleConversationStatus(
      context.id,
      wootConstants.STATUS_TYPE.RESOLVED,
      context.snoozedUntil,
      mergedAttributes
    );
  }
}

function allSelectedConversationsStatus(status) {
  if (!selectedConversations.value.length) return false;
  return selectedConversations.value.every(item => {
    return getConversationById.value(item)?.status === status;
  });
}

function toggleSelectAll(check) {
  selectAllConversations(check, conversationList);
}

const clampConversationListWidth = width =>
  Math.min(640, Math.max(300, Math.round(width)));

const loadConversationListWidth = () => {
  const defaultWidth = window.innerWidth >= 1536 ? 412 : 340;
  const storedWidth = Number(
    window.localStorage.getItem('rotta-conversations-width')
  );
  conversationListWidth.value = clampConversationListWidth(
    storedWidth || defaultWidth
  );
};

const resizeConversationList = event => {
  if (!isResizingConversationList.value) return;

  conversationListWidth.value = clampConversationListWidth(
    resizeStartWidth.value + event.clientX - resizeStartX.value
  );
};

const stopResizingConversationList = () => {
  if (!isResizingConversationList.value) return;

  isResizingConversationList.value = false;
  window.removeEventListener('pointermove', resizeConversationList);
  window.removeEventListener('pointerup', stopResizingConversationList);
  document.body.classList.remove('rotta-is-resizing-conversations');
  window.localStorage.setItem(
    'rotta-conversations-width',
    String(conversationListWidth.value)
  );
};

const startResizingConversationList = event => {
  event.preventDefault();
  isResizingConversationList.value = true;
  resizeStartX.value = event.clientX;
  resizeStartWidth.value = conversationListWidth.value;
  window.addEventListener('pointermove', resizeConversationList);
  window.addEventListener('pointerup', stopResizingConversationList);
  document.body.classList.add('rotta-is-resizing-conversations');
};

useEmitter('fetch_conversation_stats', () => {
  if (hasAppliedFiltersOrActiveFolders.value) return;
  store.dispatch('conversationStats/get', conversationFilters.value);
});

onMounted(() => {
  loadConversationListWidth();
  store.dispatch('setChatListFilters', conversationFilters.value);
  setFiltersFromUISettings();
  store.dispatch('setChatStatusFilter', activeStatus.value);
  store.dispatch('setChatSortFilter', activeSortBy.value);
  resetAndFetchData();
  if (hasActiveFolders.value) {
    store.dispatch('campaigns/get');
  }
});

onBeforeUnmount(() => {
  stopResizingConversationList();
  clearTimeout(conversationSearchTimer);
});

const deleteConversationDialogRef = ref(null);
const selectedConversationId = ref(null);

async function deleteConversation() {
  try {
    await store.dispatch('deleteConversation', selectedConversationId.value);
    redirectToConversationList();
    selectedConversationId.value = null;
    deleteConversationDialogRef.value.close();
    useAlert(t('CONVERSATION.SUCCESS_DELETE_CONVERSATION'));
  } catch (error) {
    useAlert(t('CONVERSATION.FAIL_DELETE_CONVERSATION'));
  }
}

const handleDelete = conversationId => {
  selectedConversationId.value = conversationId;
  deleteConversationDialogRef.value.open();
};

provide('selectConversation', selectConversation);
provide('deSelectConversation', deSelectConversation);
provide('assignTeam', onAssignTeam);
provide('assignLabels', onAssignLabels);
provide('removeLabels', onRemoveLabels);
provide('updateConversationStatus', handleResolveConversation);
provide('markAsUnread', markAsUnread);
provide('markAsRead', markAsRead);
provide('assignPriority', assignPriority);
provide('togglePinned', togglePinned);
provide('isConversationSelected', isConversationSelected);
provide('deleteConversation', handleDelete);

watch(activeTeam, () => resetAndFetchData());

watch(
  computed(() => props.conversationInbox),
  () => resetAndFetchData()
);
watch(
  computed(() => props.label),
  () => resetAndFetchData()
);
watch(
  computed(() => props.conversationType),
  () => resetAndFetchData()
);

watch(
  computed(() => props.conversationStatus),
  value => {
    activeStatus.value = value || wootConstants.STATUS_TYPE.OPEN;
    resetAndFetchData();
  }
);

watch(activeFolder, (newVal, oldVal) => {
  if (newVal !== oldVal) {
    store.dispatch('customViews/setActiveConversationFolder', newVal || null);
  }
  resetAndFetchData();
});

watch(chatLists, () => {
  chatsOnView.value = conversationList.value;
});

watch(conversationFilters, (newVal, oldVal) => {
  if (newVal !== oldVal) {
    store.dispatch('updateChatListFilters', newVal);
  }
});

watch(conversationSearchQuery, searchQuery => {
  scheduleConversationSearch(searchQuery);
});
</script>

<template>
  <div
    class="flex flex-col flex-shrink-0 conversations-list-wrap bg-n-surface-1 relative rotta-conversations-list"
    :style="{ '--rotta-conversation-list-width': `${conversationListWidth}px` }"
    :class="[{ hidden: !showConversationList }]"
  >
    <slot />
    <div
      class="rotta-chat-list-resizer"
      role="separator"
      aria-orientation="vertical"
      :aria-label="resizeConversationsLabel"
      @pointerdown="startResizingConversationList"
    >
      <span class="rotta-chat-list-resizer__grip" aria-hidden="true" />
    </div>
    <ChatListHeader
      :page-title="pageTitle"
      :has-applied-filters="hasAppliedFilters"
      :has-active-folders="hasActiveFolders"
      :active-status="activeStatus"
      :is-on-expanded-layout="isOnExpandedLayout"
      :conversation-stats="conversationStats"
      :is-list-loading="chatListLoading && !conversationList.length"
      :search-query="conversationSearchQuery"
      :show-rotta-shortcuts="showRottaConversationShortcuts"
      :is-marking-all-as-read="isMarkingAllAsRead"
      @add-folders="onClickOpenAddFoldersModal"
      @delete-folders="onClickOpenDeleteFoldersModal"
      @filters-modal="onToggleAdvanceFiltersModal"
      @reset-filters="resetAndFetchData"
      @basic-filter-change="onBasicFilterChange"
      @update-search-query="conversationSearchQuery = $event"
      @mark-all-as-read="markAllVisibleAsRead"
    />

    <TeleportWithDirection
      v-if="showAddFoldersModal"
      to="#saveFilterTeleportTarget"
    >
      <SaveCustomView
        v-model="appliedFilter"
        :custom-views-query="foldersQuery"
        :open-last-saved-item="openLastSavedItemInFolder"
        @close="onCloseAddFoldersModal"
      />
    </TeleportWithDirection>

    <DeleteCustomViews
      v-if="showDeleteFoldersModal"
      v-model:show="showDeleteFoldersModal"
      :active-custom-view="activeFolder"
      :custom-views-id="foldersId"
      :open-last-item-after-delete="openLastItemAfterDeleteInFolder"
      @close="onCloseDeleteFoldersModal"
    />

    <p
      v-if="!chatListLoading && !conversationList.length"
      class="flex overflow-auto justify-center items-center p-4"
    >
      {{ $t('CHAT_LIST.LIST.404') }}
    </p>
    <p
      v-if="
        conversationSearchQuery.trim() &&
        !isSearchingConversations &&
        !filteredConversationList.length
      "
      class="flex overflow-auto justify-center items-center p-4 text-sm text-n-slate-10"
    >
      {{ noSearchResultsLabel }}
    </p>
    <ConversationBulkActions
      :conversations="selectedConversations"
      :all-conversations-selected="allConversationsSelected"
      :show-open-action="allSelectedConversationsStatus('open')"
      :show-resolved-action="allSelectedConversationsStatus('resolved')"
      :show-snoozed-action="allSelectedConversationsStatus('snoozed')"
      :class="isOnExpandedLayout && 'sm:!w-[24rem] !w-full'"
      @select-all-conversations="toggleSelectAll"
    />
    <ConversationList
      :conversation-list="filteredConversationList"
      :is-loading="chatListLoading || isSearchingConversations"
      :show-end-of-list-message="showEndOfListMessage"
      :label="label"
      :team-id="teamId"
      :folders-id="foldersId"
      :conversation-type="conversationType"
      :show-assignee="showAssigneeInConversationCard"
      :is-on-expanded-layout="isOnExpandedLayout"
      @load-more="loadMoreConversations"
    />
    <Dialog
      ref="deleteConversationDialogRef"
      type="alert"
      :title="
        $t('CONVERSATION.DELETE_CONVERSATION.TITLE', {
          conversationId: selectedConversationId,
        })
      "
      :description="$t('CONVERSATION.DELETE_CONVERSATION.DESCRIPTION')"
      :confirm-button-label="$t('CONVERSATION.DELETE_CONVERSATION.CONFIRM')"
      @confirm="deleteConversation"
      @close="selectedConversationId = null"
    />
    <TeleportWithDirection
      v-if="showAdvancedFilters"
      to="#conversationFilterTeleportTarget"
    >
      <ConversationFilter
        v-model="appliedFilter"
        :folder-name="activeFolderName"
        :is-folder-view="hasActiveFolders"
        @apply-filter="onApplyFilter"
        @update-folder="onUpdateSavedFilter"
        @close="closeAdvanceFiltersModal"
      />
    </TeleportWithDirection>
    <ConversationResolveAttributesModal
      ref="resolveAttributesModalRef"
      @submit="handleResolveWithAttributes"
    />
  </div>
</template>

<style scoped>
.rotta-conversations-list {
  width: var(--rotta-conversation-list-width, 340px);
  min-width: 300px;
  max-width: 640px;
}

.rotta-chat-list-resizer {
  position: absolute;
  inset-block: 0;
  inset-inline-end: -7px;
  z-index: 30;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 14px;
  cursor: col-resize;
  touch-action: none;
}

.rotta-chat-list-resizer__grip {
  width: 2px;
  height: 40px;
  border-radius: 999px;
  background: transparent;
  transition:
    background-color 120ms ease,
    height 120ms ease;
}

.rotta-chat-list-resizer:hover .rotta-chat-list-resizer__grip,
.rotta-chat-list-resizer:focus-visible .rotta-chat-list-resizer__grip {
  height: 56px;
  background: var(--color-n-brand, #2563eb);
}

:global(body.rotta-is-resizing-conversations) {
  cursor: col-resize;
  user-select: none;
}

@media (max-width: 767px) {
  .rotta-conversations-list {
    width: 100%;
    min-width: 0;
    max-width: none;
  }

  .rotta-chat-list-resizer {
    display: none;
  }
}
</style>
