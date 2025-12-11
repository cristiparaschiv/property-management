import api from './api';

export const searchService = {
  search: async (query) => {
    const response = await api.get('/search', {
      params: { q: query }
    });
    // API returns { success, data: { tenants, invoices, providers, total_count } }
    return response.data.data;
  },
};
