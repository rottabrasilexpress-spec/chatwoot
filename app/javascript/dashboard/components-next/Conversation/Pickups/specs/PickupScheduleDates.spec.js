import { mount } from '@vue/test-utils';
import PickupScheduleDates from '../PickupScheduleDates.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key =>
      ({
        'ROTTA_PICKUP.COLLECTION_SHORT': 'Coleta',
        'ROTTA_PICKUP.DELIVERY_SHORT': 'Entrega',
        'ROTTA_PICKUP.PENDING': 'Pendente',
      })[key],
  }),
}));

const pickup = {
  starts_on: '2026-11-21',
  ends_on: '2026-11-22',
};

describe('PickupScheduleDates', () => {
  it('shows the two dates with their labels and colors in the conversation header', () => {
    const wrapper = mount(PickupScheduleDates, {
      props: { schedule: { ...pickup, delivery_on: '2026-11-23' } },
    });
    expect(wrapper.get('.text-n-ruby-11').text()).toBe(
      'Coleta 21/11/2026 até 22/11'
    );
    expect(wrapper.get('.text-n-teal-11').text()).toBe('Entrega 23/11/2026');
  });

  it('shows only the dates and a green separator in the conversation card', () => {
    const wrapper = mount(PickupScheduleDates, {
      props: {
        inline: true,
        schedule: { ...pickup, delivery_on: '2026-11-23' },
      },
    });
    expect(wrapper.get('.text-n-ruby-11').text()).toBe('21/11/2026 até 22/11');
    expect(wrapper.get('.text-n-teal-11').text()).toMatch(/^–\s*23\/11\/2026$/);
    expect(wrapper.text()).not.toMatch(/Coleta|Entrega|Pendente/);
  });

  it('keeps delivery pending in the details and omits it in the compact card', () => {
    const wrapper = mount(PickupScheduleDates, { props: { schedule: pickup } });
    expect(wrapper.text()).toContain('Entrega Pendente');
    const card = mount(PickupScheduleDates, {
      props: { inline: true, schedule: pickup },
    });
    expect(card.text()).toBe('21/11/2026 até 22/11');
    expect(card.find('.text-n-teal-11').exists()).toBe(false);
  });
});
