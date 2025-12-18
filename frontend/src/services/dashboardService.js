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

  getTenantBalances: async () => {
    const response = await api.get('/dashboard/tenant-balances');
    return response.data;
  },

  getOverdueInvoices: async () => {
    const response = await api.get('/dashboard/overdue-invoices');
    return response.data;
  },

  getUtilityEvolutionChart: async (months = 12) => {
    const response = await api.get('/dashboard/charts/utility-evolution', { params: { months } });
    return response.data;
  },

  getCalendarEvents: async (startDate, endDate) => {
    const params = {};
    if (startDate) params.start_date = startDate;
    if (endDate) params.end_date = endDate;
    const response = await api.get('/dashboard/calendar', { params });
    return response.data;
  },

  getCollectionReport: async (year, month) => {
    const params = {};
    if (year) params.year = year;
    if (month) params.month = month;
    const response = await api.get('/dashboard/reports/collection', { params });
    return response.data;
  },

  getTenantStatement: async (tenantId, startDate, endDate) => {
    const params = {};
    if (startDate) params.start_date = startDate;
    if (endDate) params.end_date = endDate;
    const response = await api.get(`/dashboard/reports/tenant-statement/${tenantId}`, { params });
    return response.data;
  },
};
