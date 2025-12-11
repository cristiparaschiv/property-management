import axios from 'axios';
import useAuthStore from '../stores/authStore';

const api = axios.create({
  baseURL: '/api',
  headers: {
    'Content-Type': 'application/json',
  },
});

// State-changing HTTP methods that require CSRF protection
const CSRF_METHODS = ['post', 'put', 'delete', 'patch'];

// Request interceptor to add auth token and CSRF token
api.interceptors.request.use(
  (config) => {
    const { token, csrfToken } = useAuthStore.getState();

    // Add JWT authorization token
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }

    // Add CSRF token for state-changing requests
    if (csrfToken && CSRF_METHODS.includes(config.method?.toLowerCase())) {
      config.headers['X-CSRF-Token'] = csrfToken;
    }

    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Helper function to refresh CSRF token
const refreshCsrfToken = async () => {
  try {
    const token = useAuthStore.getState().token;
    if (!token) return null;

    const response = await axios.post('/api/auth/csrf-refresh', {}, {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });

    if (response.data?.success && response.data?.data?.csrf_token) {
      useAuthStore.getState().setCsrfToken(response.data.data.csrf_token);
      return response.data.data.csrf_token;
    }
    return null;
  } catch (error) {
    console.error('Failed to refresh CSRF token:', error);
    return null;
  }
};

// Response interceptor to handle errors
api.interceptors.response.use(
  (response) => {
    // Update CSRF token if returned in response
    if (response.data?.data?.csrf_token) {
      useAuthStore.getState().setCsrfToken(response.data.data.csrf_token);
    }
    return response;
  },
  async (error) => {
    const originalRequest = error.config;

    if (error.response?.status === 401) {
      // Don't redirect for login endpoint - let the Login page handle the error
      const isLoginRequest = originalRequest?.url?.includes('/auth/login');

      if (!isLoginRequest) {
        // Token expired or invalid - logout and redirect
        useAuthStore.getState().logout();
        window.location.href = '/login';
      }

      return Promise.reject(error);
    }

    // Handle CSRF token errors - try to refresh token and retry once
    if (error.response?.status === 403 &&
        error.response?.data?.code === 'CSRF_INVALID' &&
        !originalRequest._csrfRetry) {
      originalRequest._csrfRetry = true;

      const newCsrfToken = await refreshCsrfToken();
      if (newCsrfToken) {
        originalRequest.headers['X-CSRF-Token'] = newCsrfToken;
        return api(originalRequest);
      }
    }

    return Promise.reject(error);
  }
);

export default api;
