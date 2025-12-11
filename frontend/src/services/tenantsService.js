import api from './api';

export const tenantsService = {
  getAll: async (isActive) => {
    const params = {};
    if (isActive !== undefined) params.is_active = isActive;
    const response = await api.get('/tenants', { params });
    return response.data;
  },

  getById: async (id) => {
    const response = await api.get(`/tenants/${id}`);
    return response.data;
  },

  create: async (data) => {
    const response = await api.post('/tenants', data);
    return response.data;
  },

  update: async (id, data) => {
    const response = await api.put(`/tenants/${id}`, data);
    return response.data;
  },

  delete: async (id) => {
    const response = await api.delete(`/tenants/${id}`);
    return response.data;
  },

  updatePercentages: async (id, percentages) => {
    const response = await api.put(`/tenants/${id}/percentages`, { percentages });
    return response.data;
  },
};
