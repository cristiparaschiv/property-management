import api from './api';

export const utilityProvidersService = {
  getAll: async (type, isActive) => {
    const params = {};
    if (type) params.type = type;
    if (isActive !== undefined) params.active = isActive;
    const response = await api.get('/utility-providers', { params });
    return response.data;
  },

  getById: async (id) => {
    const response = await api.get(`/utility-providers/${id}`);
    return response.data;
  },

  create: async (data) => {
    const response = await api.post('/utility-providers', data);
    return response.data;
  },

  update: async (id, data) => {
    const response = await api.put(`/utility-providers/${id}`, data);
    return response.data;
  },

  delete: async (id) => {
    const response = await api.delete(`/utility-providers/${id}`);
    return response.data;
  },
};
