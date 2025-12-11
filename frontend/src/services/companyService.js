import api from './api';

export const companyService = {
  get: async () => {
    const response = await api.get('/company');
    return response.data;
  },

  create: async (data) => {
    const response = await api.post('/company', data);
    return response.data;
  },

  update: async (data) => {
    const response = await api.put('/company', data);
    return response.data;
  },
};
