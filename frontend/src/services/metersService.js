import api from './api';

export const metersService = {
  getAll: async () => {
    const response = await api.get('/meters');
    return response.data;
  },

  getById: async (id) => {
    const response = await api.get(`/meters/${id}`);
    return response.data;
  },

  create: async (data) => {
    const response = await api.post('/meters', data);
    return response.data;
  },

  update: async (id, data) => {
    const response = await api.put(`/meters/${id}`, data);
    return response.data;
  },

  delete: async (id) => {
    const response = await api.delete(`/meters/${id}`);
    return response.data;
  },
};
