import api from './api';

export const activityLogsService = {
  getAll: async (params = {}) => {
    const response = await api.get('/activity-logs', { params });
    return response.data;
  },
  getRecent: async (limit = 10) => {
    const response = await api.get('/activity-logs/recent', { params: { limit } });
    return response.data;
  },
};

export default activityLogsService;
