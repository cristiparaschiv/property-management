import api from './api';

export const loansService = {
  getAll: async () => {
    const response = await api.get('/loans');
    return response.data;
  },

  getById: async (id) => {
    const response = await api.get(`/loans/${id}`);
    return response.data;
  },

  update: async (id, data) => {
    const response = await api.put(`/loans/${id}`, data);
    return response.data;
  },

  addEntry: async (id, data) => {
    const response = await api.post(`/loans/${id}/entries`, data);
    return response.data;
  },

  deleteEntry: async (id, entryId) => {
    const response = await api.delete(`/loans/${id}/entries/${entryId}`);
    return response.data;
  },
};

export default loansService;
