import api from './api';

export const meteredInputsService = {
  getAll: async (params = {}) => {
    const response = await api.get('/metered-inputs', { params });
    return response.data;
  },

  save: async (data) => {
    const response = await api.post('/metered-inputs', data);
    return response.data;
  },

  delete: async (id) => {
    const response = await api.delete(`/metered-inputs/${id}`);
    return response.data;
  },
};
