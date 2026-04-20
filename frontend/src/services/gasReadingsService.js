import api from './api';

export const gasReadingsService = {
  getAll: async (params = {}) => {
    const response = await api.get('/gas-readings', { params });
    return response.data;
  },

  getById: async (id) => {
    const response = await api.get(`/gas-readings/${id}`);
    return response.data;
  },

  create: async (data) => {
    const response = await api.post('/gas-readings', data);
    return response.data;
  },

  update: async (id, data) => {
    const response = await api.put(`/gas-readings/${id}`, data);
    return response.data;
  },

  delete: async (id) => {
    const response = await api.delete(`/gas-readings/${id}`);
    return response.data;
  },
};
