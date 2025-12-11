import api from './api';

export const receivedInvoicesService = {
  getAll: async (providerId, type, isPaid) => {
    const params = {};
    if (providerId) params.provider_id = providerId;
    if (type) params.type = type;
    if (isPaid !== undefined) params.paid = isPaid;
    const response = await api.get('/received-invoices', { params });
    return response.data;
  },

  getByPeriod: async (year, month) => {
    const response = await api.get(`/received-invoices/period/${year}/${month}`);
    return response.data;
  },

  getById: async (id) => {
    const response = await api.get(`/received-invoices/${id}`);
    return response.data;
  },

  create: async (data) => {
    const response = await api.post('/received-invoices', data);
    return response.data;
  },

  update: async (id, data) => {
    const response = await api.put(`/received-invoices/${id}`, data);
    return response.data;
  },

  delete: async (id) => {
    const response = await api.delete(`/received-invoices/${id}`);
    return response.data;
  },

  markPaid: async (id, paidDate) => {
    const response = await api.post(`/received-invoices/${id}/mark-paid`, { paid_date: paidDate });
    return response.data;
  },

  markPaidNow: async (id) => {
    const response = await api.post(`/received-invoices/${id}/paid-now`);
    return response.data;
  },
};
