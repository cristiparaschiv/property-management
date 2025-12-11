import api from './api';

export const dashboardService = {
  getSummary: async () => {
    const response = await api.get('/dashboard/summary');
    return response.data;
  },

  getRevenueChart: async (months = 12) => {
    const response = await api.get('/dashboard/charts/revenue', { params: { months } });
    return response.data;
  },

  getUtilityCostsChart: async (year, month) => {
    const params = {};
    if (year) params.year = year;
    if (month) params.month = month;
    const response = await api.get('/dashboard/charts/utilities', { params });
    return response.data;
  },

  getExpensesTrendChart: async (months = 6) => {
    const response = await api.get('/dashboard/charts/expenses-trend', { params: { months } });
    return response.data;
  },

  getInvoicesStatusChart: async () => {
    const response = await api.get('/dashboard/charts/invoices-status');
    return response.data;
  },

  getCashFlowChart: async (months = 12) => {
    const response = await api.get('/dashboard/charts/cash-flow', { params: { months } });
    return response.data;
  },
};
