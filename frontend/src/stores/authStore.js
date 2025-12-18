import { create } from 'zustand';

// Note: JWT is now stored in HttpOnly cookie (not accessible via JavaScript)
// We only store user info and CSRF token in localStorage
const useAuthStore = create((set, get) => ({
  csrfToken: localStorage.getItem('csrf_token') || null,
  user: JSON.parse(localStorage.getItem('user') || 'null'),
  isAuthenticated: !!localStorage.getItem('user'),

  setAuth: (user, csrfToken) => {
    localStorage.setItem('user', JSON.stringify(user));
    if (csrfToken) {
      localStorage.setItem('csrf_token', csrfToken);
    }
    set({ user, csrfToken: csrfToken || get().csrfToken, isAuthenticated: true });
  },

  setCsrfToken: (csrfToken) => {
    localStorage.setItem('csrf_token', csrfToken);
    set({ csrfToken });
  },

  logout: () => {
    localStorage.removeItem('user');
    localStorage.removeItem('csrf_token');
    set({ user: null, csrfToken: null, isAuthenticated: false });
  },

  updateUser: (user) => {
    localStorage.setItem('user', JSON.stringify(user));
    set({ user });
  },
}));

export default useAuthStore;
