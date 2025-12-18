import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { colors, lightTheme, darkTheme, chartColors } from '../styles/theme/tokens';

const ThemeContext = createContext();

export const ThemeProvider = ({ children }) => {
  const [isDarkMode, setIsDarkMode] = useState(() => {
    const saved = localStorage.getItem('darkMode');
    return saved ? JSON.parse(saved) : false;
  });

  useEffect(() => {
    localStorage.setItem('darkMode', JSON.stringify(isDarkMode));

    // Set data-theme attribute on document for CSS styling
    document.documentElement.setAttribute('data-theme', isDarkMode ? 'dark' : 'light');

    // Update meta theme-color for mobile browsers
    let metaTheme = document.querySelector('meta[name="theme-color"]');
    if (!metaTheme) {
      metaTheme = document.createElement('meta');
      metaTheme.name = 'theme-color';
      document.head.appendChild(metaTheme);
    }
    metaTheme.setAttribute('content', isDarkMode ? '#0f172a' : '#f8fafc');

    // Add transition class for smooth theme switching
    document.documentElement.classList.add('pm-theme-transition');
    const timeout = setTimeout(() => {
      document.documentElement.classList.remove('pm-theme-transition');
    }, 300);

    return () => clearTimeout(timeout);
  }, [isDarkMode]);

  const toggleTheme = useCallback(() => {
    setIsDarkMode(prev => !prev);
  }, []);

  // Provide theme colors for components that need programmatic access
  const themeColors = isDarkMode ? darkTheme : lightTheme;

  // Provide chart colors
  const getChartColors = useCallback(() => chartColors, []);

  // Get semantic color with optional variant
  const getColor = useCallback((colorName, variant = 'main') => {
    if (colors[colorName]) {
      if (typeof colors[colorName] === 'object') {
        return colors[colorName][variant] || colors[colorName].main || colors[colorName][500];
      }
      return colors[colorName];
    }
    return colorName;
  }, []);

  const value = {
    isDarkMode,
    toggleTheme,
    themeColors,
    colors,
    chartColors,
    getChartColors,
    getColor,
  };

  return (
    <ThemeContext.Provider value={value}>
      {children}
    </ThemeContext.Provider>
  );
};

export const useTheme = () => {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error('useTheme must be used within ThemeProvider');
  }
  return context;
};

export default ThemeContext;
