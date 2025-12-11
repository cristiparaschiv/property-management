import api from './api';

export const exchangeRatesService = {
  getCurrent: async () => {
    const response = await api.get('/exchange-rates/current');
    return response.data;
  },

  getByDate: async (date) => {
    const response = await api.get(`/exchange-rates/${date}`);
    return response.data;
  },
};
