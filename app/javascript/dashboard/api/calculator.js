/* global axios */

const CalculatorAPI = {
  calculate(accountId, payload) {
    return axios.post(`/api/v1/accounts/${accountId}/calculator/calculate`, {
      calculator: payload,
    });
  },
};

export default CalculatorAPI;
