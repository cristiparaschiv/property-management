import api from './api';

export const utilityCalculationsService = {
  getAll: async () => {
    const response = await api.get('/utility-calculations');
    return response.data;
  },

  preview: async (year, month) => {
    const response = await api.get(`/utility-calculations/preview/${year}/${month}`);
    return response.data;
  },

  getById: async (id) => {
    const response = await api.get(`/utility-calculations/${id}`);
    return response.data;
  },

  create: async (data) => {
    const response = await api.post('/utility-calculations', data);
    return response.data;
  },

  finalize: async (id) => {
    const response = await api.post(`/utility-calculations/${id}/finalize`);
    return response.data;
  },
};
