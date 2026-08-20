import { FEATURE_FLAGS } from '../../../../featureFlags';
import { frontendURL } from '../../../../helper/URLHelper';

import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';
import FollowUp from './FollowUp.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/labels'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'labels_wrapper',
          meta: {
            permissions: ['administrator'],
          },
          redirect: to => {
            return { name: 'labels_list', params: to.params };
          },
        },
        {
          path: 'list',
          name: 'labels_list',
          meta: {
            featureFlag: FEATURE_FLAGS.LABELS,
            permissions: ['administrator'],
          },
          component: Index,
        },
        {
          path: 'follow-up',
          name: 'rotta_follow_up',
          meta: {
            permissions: ['administrator'],
          },
          component: FollowUp,
        },
      ],
    },
  ],
};
