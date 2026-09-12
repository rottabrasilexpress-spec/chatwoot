import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import CalculatorIndex from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/calculator'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'calculator_index',
          component: CalculatorIndex,
        },
      ],
    },
  ],
};
