import api from './api';

export const meterReadingsService = {
  getAll: async (meterId) => {
    const params = {};
    if (meterId) params.meter_id = meterId;
    const response = await api.get('/meter-readings', { params });
    return response.data;
  },

  getByPeriod: async (year, month) => {
    const response = await api.get(`/meter-readings/period/${year}/${month}`);
    return response.data;
  },

  getById: async (id) => {
    const response = await api.get(`/meter-readings/${id}`);
    return response.data;
  },

  create: async (data) => {
    const response = await api.post('/meter-readings', data);
    return response.data;
  },

  update: async (id, data) => {
    const response = await api.put(`/meter-readings/${id}`, data);
    return response.data;
  },

  delete: async (id) => {
    const response = await api.delete(`/meter-readings/${id}`);
    return response.data;
  },

  createBatch: async (readings) => {
    const response = await api.post('/meter-readings/batch', { readings });
    return response.data;
  },
};
