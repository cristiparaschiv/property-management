/**
 * Design Tokens for Property Management System
 * Slate & Emerald Theme
 */

export const colors = {
  // Primary - Emerald
  primary: {
    50: '#ecfdf5',
    100: '#d1fae5',
    200: '#a7f3d0',
    300: '#6ee7b7',
    400: '#34d399',
    500: '#10b981', // Main primary
    600: '#059669',
    700: '#047857',
    800: '#065f46',
    900: '#064e3b',
  },

  // Neutral - Slate
  slate: {
    50: '#f8fafc',
    100: '#f1f5f9',
    200: '#e2e8f0',
    300: '#cbd5e1',
    400: '#94a3b8',
    500: '#64748b',
    600: '#475569',
    700: '#334155',
    800: '#1e293b',
    900: '#0f172a',
    950: '#020617',
  },

  // Semantic colors
  success: {
    light: '#d1fae5',
    main: '#10b981',
    dark: '#065f46',
  },
  warning: {
    light: '#fef3c7',
    main: '#f59e0b',
    dark: '#b45309',
  },
  error: {
    light: '#fee2e2',
    main: '#ef4444',
    dark: '#b91c1c',
  },
  info: {
    light: '#dbeafe',
    main: '#3b82f6',
    dark: '#1d4ed8',
  },
};

export const spacing = {
  xs: '4px',
  sm: '8px',
  md: '16px',
  lg: '24px',
  xl: '32px',
  '2xl': '48px',
  '3xl': '64px',
};

export const borderRadius = {
  sm: '4px',
  md: '8px',
  lg: '12px',
  xl: '16px',
  '2xl': '24px',
  full: '9999px',
};

export const shadows = {
  sm: '0 1px 2px 0 rgba(0, 0, 0, 0.05)',
  md: '0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -2px rgba(0, 0, 0, 0.1)',
  lg: '0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -4px rgba(0, 0, 0, 0.1)',
  xl: '0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 8px 10px -6px rgba(0, 0, 0, 0.1)',
  glass: '0 8px 32px 0 rgba(0, 0, 0, 0.12)',
  glassDark: '0 8px 32px 0 rgba(0, 0, 0, 0.4)',
};

export const transitions = {
  fast: '150ms ease',
  normal: '250ms ease',
  slow: '350ms ease',
  bounce: '300ms cubic-bezier(0.34, 1.56, 0.64, 1)',
};

export const typography = {
  fontFamily: "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', sans-serif",
  fontSize: {
    xs: '12px',
    sm: '14px',
    md: '16px',
    lg: '18px',
    xl: '20px',
    '2xl': '24px',
    '3xl': '30px',
    '4xl': '36px',
  },
  fontWeight: {
    normal: 400,
    medium: 500,
    semibold: 600,
    bold: 700,
  },
  lineHeight: {
    tight: 1.25,
    normal: 1.5,
    relaxed: 1.75,
  },
};

// Light theme semantic mappings
export const lightTheme = {
  bg: {
    primary: colors.slate[50],
    secondary: '#ffffff',
    tertiary: colors.slate[100],
    elevated: '#ffffff',
    glass: 'rgba(255, 255, 255, 0.8)',
    sidebar: colors.slate[900],
    sidebarGradient: `linear-gradient(180deg, ${colors.slate[900]} 0%, ${colors.slate[800]} 100%)`,
  },
  text: {
    primary: colors.slate[900],
    secondary: colors.slate[600],
    tertiary: colors.slate[400],
    inverse: '#ffffff',
    muted: colors.slate[500],
  },
  border: {
    default: colors.slate[200],
    strong: colors.slate[300],
    subtle: colors.slate[100],
  },
};

// Dark theme semantic mappings
export const darkTheme = {
  bg: {
    primary: colors.slate[900],
    secondary: colors.slate[800],
    tertiary: colors.slate[700],
    elevated: colors.slate[800],
    glass: 'rgba(30, 41, 59, 0.8)',
    sidebar: colors.slate[950],
    sidebarGradient: `linear-gradient(180deg, ${colors.slate[950]} 0%, ${colors.slate[900]} 100%)`,
  },
  text: {
    primary: colors.slate[50],
    secondary: colors.slate[300],
    tertiary: colors.slate[500],
    inverse: colors.slate[900],
    muted: colors.slate[400],
  },
  border: {
    default: colors.slate[700],
    strong: colors.slate[600],
    subtle: colors.slate[800],
  },
};

// Chart colors
export const chartColors = {
  primary: colors.primary[500],
  secondary: colors.info.main,
  tertiary: colors.warning.main,
  quaternary: colors.error.main,
  palette: [
    colors.primary[500],
    colors.info.main,
    colors.warning.main,
    colors.error.main,
    colors.primary[300],
    colors.info.dark,
  ],
  gradients: {
    primary: {
      start: colors.primary[500],
      end: colors.primary[200],
    },
    success: {
      start: colors.success.main,
      end: colors.success.light,
    },
    error: {
      start: colors.error.main,
      end: colors.error.light,
    },
  },
};
