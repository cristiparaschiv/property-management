import api from './api';

export const googleDriveService = {
  // OAuth
  getAuthUrl: () => api.get('/google/auth-url'),
  getStatus: () => api.get('/google/status'),
  disconnect: () => api.post('/google/disconnect'),

  // Backups
  createBackup: () => api.post('/google/backup'),
  getBackups: (params = {}) => api.get('/google/backups', { params }),
  getDriveBackups: () => api.get('/google/backups/drive'),
  restoreBackup: (id) => api.post(`/google/restore/${id}`),
  deleteBackup: (id, deleteFromDrive = false) =>
    api.delete(`/google/backups/${id}`, {
      params: { delete_from_drive: deleteFromDrive ? 1 : 0 },
    }),
};

export default googleDriveService;
