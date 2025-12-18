import api from './api';

export const invoicesService = {
  getAll: async (tenantId, type, isPaid) => {
    const params = {};
    if (tenantId) params.tenant_id = tenantId;
    if (type) params.type = type;
    if (isPaid !== undefined) params.paid = isPaid;
    const response = await api.get('/invoices', { params });
    return response.data;
  },

  getNextNumber: async () => {
    const response = await api.get('/invoices/next-number');
    return response.data;
  },

  getById: async (id) => {
    const response = await api.get(`/invoices/${id}`);
    return response.data;
  },

  createRent: async (data) => {
    const response = await api.post('/invoices/rent', data);
    return response.data;
  },

  createUtility: async (data) => {
    const response = await api.post('/invoices/utility', data);
    return response.data;
  },

  createGeneric: async (data) => {
    const response = await api.post('/invoices/generic', data);
    return response.data;
  },

  downloadPDF: async (id) => {
    const response = await api.get(`/invoices/${id}/pdf`, {
      responseType: 'blob',
    });
    // Return both blob and filename from Content-Disposition header
    const contentDisposition = response.headers['content-disposition'];
    let filename = 'invoice.pdf';
    if (contentDisposition) {
      const match = contentDisposition.match(/filename="?([^";\n]+)"?/);
      if (match && match[1]) {
        filename = match[1];
      }
    }
    return { blob: response.data, filename };
  },

  markPaid: async (id, paidDate) => {
    const response = await api.post(`/invoices/${id}/mark-paid`, { paid_date: paidDate });
    return response.data;
  },

  addItem: async (id, data) => {
    const response = await api.post(`/invoices/${id}/items`, data);
    return response.data;
  },

  delete: async (id) => {
    const response = await api.delete(`/invoices/${id}`);
    return response.data;
  },
};
