import { frontendURL } from '../../../../helper/URLHelper';
import { ROLES } from 'dashboard/constants/permissions.js';
import SettingsWrapper from '../SettingsWrapper.vue';

const CalculatorIndex = () => import('./Index.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/calculator'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'calculator_index',
          meta: {
            permissions: ROLES,
          },
          component: CalculatorIndex,
        },
      ],
    },
  ],
};
