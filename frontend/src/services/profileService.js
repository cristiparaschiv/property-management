import api from './api';

export const profileService = {
  get: async () => {
    const response = await api.get('/profile');
    return response.data;
  },

  update: async (data) => {
    const response = await api.put('/profile', data);
    return response.data;
  },
};
