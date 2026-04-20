import api from './api';

export const waterReadingsService = {
  getAll: async (params = {}) => {
    const response = await api.get('/water-readings', { params });
    return response.data;
  },

  getById: async (id) => {
    const response = await api.get(`/water-readings/${id}`);
    return response.data;
  },

  create: async (data) => {
    const response = await api.post('/water-readings', data);
    return response.data;
  },

  update: async (id, data) => {
    const response = await api.put(`/water-readings/${id}`, data);
    return response.data;
  },

  delete: async (id) => {
    const response = await api.delete(`/water-readings/${id}`);
    return response.data;
  },
};
