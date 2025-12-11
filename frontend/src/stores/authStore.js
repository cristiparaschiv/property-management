import { create } from 'zustand';

const useAuthStore = create((set, get) => ({
  token: localStorage.getItem('token') || null,
  csrfToken: localStorage.getItem('csrf_token') || null,
  user: JSON.parse(localStorage.getItem('user') || 'null'),
  isAuthenticated: !!localStorage.getItem('token'),

  setAuth: (token, user, csrfToken) => {
    localStorage.setItem('token', token);
    localStorage.setItem('user', JSON.stringify(user));
    if (csrfToken) {
      localStorage.setItem('csrf_token', csrfToken);
    }
    set({ token, user, csrfToken: csrfToken || get().csrfToken, isAuthenticated: true });
  },

  setCsrfToken: (csrfToken) => {
    localStorage.setItem('csrf_token', csrfToken);
    set({ csrfToken });
  },

  logout: () => {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    localStorage.removeItem('csrf_token');
    set({ token: null, user: null, csrfToken: null, isAuthenticated: false });
  },

  updateUser: (user) => {
    localStorage.setItem('user', JSON.stringify(user));
    set({ user });
  },
}));

export default useAuthStore;
