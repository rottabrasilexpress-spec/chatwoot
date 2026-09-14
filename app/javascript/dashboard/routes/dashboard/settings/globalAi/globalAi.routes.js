import { frontendURL } from '../../../../helper/URLHelper';
import { ROLES } from 'dashboard/constants/permissions.js';
import SettingsWrapper from '../SettingsWrapper.vue';
import GlobalAiAssistant from './GlobalAiAssistant.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/ask-ai'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'global_ai_assistant',
          meta: { permissions: ROLES },
          component: GlobalAiAssistant,
        },
      ],
    },
  ],
};
