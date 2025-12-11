import api from './api';

export const reportsService = {
  getInvoicesReport: async (filters) => {
    const response = await api.get('/reports/invoices', { params: filters });
    return response.data;
  },

  getPaymentsReport: async (filters) => {
    const response = await api.get('/reports/payments', { params: filters });
    return response.data;
  },

  getTenantReport: async (tenantId, filters) => {
    const response = await api.get(`/reports/tenant/${tenantId}`, { params: filters });
    return response.data;
  },
};
