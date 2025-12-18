/**
 * Ant Design Theme Configuration
 * Property Management System - Slate & Emerald Theme
 */

import { theme as antdTheme } from 'antd';
import { colors, borderRadius, typography } from './tokens';

/**
 * Creates the Ant Design theme configuration based on dark mode state
 * @param {boolean} isDarkMode - Whether dark mode is active
 * @returns {object} Ant Design theme configuration
 */
export const createTheme = (isDarkMode) => ({
  algorithm: isDarkMode ? antdTheme.darkAlgorithm : antdTheme.defaultAlgorithm,

  token: {
    // Primary colors
    colorPrimary: isDarkMode ? colors.primary[400] : colors.primary[500],
    colorPrimaryHover: isDarkMode ? colors.primary[300] : colors.primary[600],
    colorPrimaryActive: isDarkMode ? colors.primary[500] : colors.primary[700],
    colorPrimaryBg: isDarkMode ? colors.primary[900] : colors.primary[50],
    colorPrimaryBgHover: isDarkMode ? colors.primary[800] : colors.primary[100],

    // Semantic colors
    colorSuccess: isDarkMode ? colors.primary[400] : colors.success.main,
    colorWarning: isDarkMode ? '#fbbf24' : colors.warning.main,
    colorError: isDarkMode ? '#f87171' : colors.error.main,
    colorInfo: isDarkMode ? '#60a5fa' : colors.info.main,

    // Background colors
    colorBgContainer: isDarkMode ? colors.slate[800] : '#ffffff',
    colorBgElevated: isDarkMode ? colors.slate[700] : '#ffffff',
    colorBgLayout: isDarkMode ? colors.slate[900] : colors.slate[50],
    colorBgSpotlight: isDarkMode ? colors.slate[700] : colors.slate[100],
    colorBgMask: isDarkMode ? 'rgba(0, 0, 0, 0.6)' : 'rgba(0, 0, 0, 0.45)',

    // Text colors
    colorText: isDarkMode ? colors.slate[50] : colors.slate[900],
    colorTextSecondary: isDarkMode ? colors.slate[300] : colors.slate[600],
    colorTextTertiary: isDarkMode ? colors.slate[500] : colors.slate[400],
    colorTextQuaternary: isDarkMode ? colors.slate[600] : colors.slate[300],

    // Border colors
    colorBorder: isDarkMode ? colors.slate[600] : colors.slate[200],
    colorBorderSecondary: isDarkMode ? colors.slate[700] : colors.slate[100],

    // Fill colors
    colorFill: isDarkMode ? colors.slate[700] : colors.slate[100],
    colorFillSecondary: isDarkMode ? colors.slate[800] : colors.slate[50],
    colorFillTertiary: isDarkMode ? colors.slate[900] : colors.slate[50],

    // Typography
    fontFamily: typography.fontFamily,
    fontSize: 14,
    fontSizeSM: 12,
    fontSizeLG: 16,
    fontSizeXL: 20,
    fontSizeHeading1: 38,
    fontSizeHeading2: 30,
    fontSizeHeading3: 24,
    fontSizeHeading4: 20,
    fontSizeHeading5: 16,

    // Border radius
    borderRadius: 8,
    borderRadiusSM: 4,
    borderRadiusLG: 12,
    borderRadiusXS: 2,

    // Spacing / Sizing
    controlHeight: 40,
    controlHeightSM: 32,
    controlHeightLG: 48,

    // Motion
    motionDurationFast: '150ms',
    motionDurationMid: '250ms',
    motionDurationSlow: '350ms',
    motionEaseInOut: 'cubic-bezier(0.4, 0, 0.2, 1)',
    motionEaseOut: 'cubic-bezier(0, 0, 0.2, 1)',

    // Box shadows
    boxShadow: isDarkMode
      ? '0 1px 2px 0 rgba(0, 0, 0, 0.3), 0 1px 6px -1px rgba(0, 0, 0, 0.2)'
      : '0 1px 2px 0 rgba(0, 0, 0, 0.03), 0 1px 6px -1px rgba(0, 0, 0, 0.02)',
    boxShadowSecondary: isDarkMode
      ? '0 6px 16px 0 rgba(0, 0, 0, 0.4), 0 3px 6px -4px rgba(0, 0, 0, 0.3)'
      : '0 6px 16px 0 rgba(0, 0, 0, 0.08), 0 3px 6px -4px rgba(0, 0, 0, 0.12)',
  },

  components: {
    // Card component
    Card: {
      paddingLG: 24,
      borderRadiusLG: 12,
      boxShadowTertiary: isDarkMode
        ? '0 1px 3px 0 rgba(0, 0, 0, 0.3)'
        : '0 1px 3px 0 rgba(0, 0, 0, 0.1)',
    },

    // Button component
    Button: {
      borderRadius: 8,
      controlHeight: 40,
      controlHeightSM: 32,
      controlHeightLG: 48,
      fontWeight: 500,
      primaryShadow: '0 2px 0 rgba(16, 185, 129, 0.1)',
      defaultShadow: '0 2px 0 rgba(0, 0, 0, 0.02)',
    },

    // Table component
    Table: {
      borderRadius: 12,
      headerBg: isDarkMode ? colors.slate[800] : colors.slate[50],
      headerColor: isDarkMode ? colors.slate[200] : colors.slate[600],
      headerSortActiveBg: isDarkMode ? colors.slate[700] : colors.slate[100],
      headerSortHoverBg: isDarkMode ? colors.slate[700] : colors.slate[100],
      rowHoverBg: isDarkMode ? colors.slate[700] : colors.slate[50],
      rowSelectedBg: isDarkMode ? colors.primary[900] : colors.primary[50],
      rowSelectedHoverBg: isDarkMode ? colors.primary[800] : colors.primary[100],
    },

    // Menu component (for sidebar)
    Menu: {
      darkItemBg: 'transparent',
      darkSubMenuItemBg: 'transparent',
      darkItemSelectedBg: 'rgba(16, 185, 129, 0.15)',
      darkItemHoverBg: 'rgba(255, 255, 255, 0.05)',
      darkItemSelectedColor: colors.primary[400],
      itemBorderRadius: 8,
      itemMarginInline: 8,
      iconSize: 18,
      collapsedIconSize: 20,
    },

    // Input component
    Input: {
      borderRadius: 8,
      controlHeight: 40,
      paddingInline: 12,
      activeShadow: `0 0 0 2px ${isDarkMode ? 'rgba(52, 211, 153, 0.2)' : 'rgba(16, 185, 129, 0.2)'}`,
    },

    // Select component
    Select: {
      borderRadius: 8,
      controlHeight: 40,
      optionSelectedBg: isDarkMode ? colors.primary[900] : colors.primary[50],
    },

    // Modal component
    Modal: {
      borderRadiusLG: 16,
      paddingContentHorizontalLG: 24,
      titleFontSize: 18,
    },

    // Dropdown component
    Dropdown: {
      borderRadiusLG: 12,
      controlItemBgHover: isDarkMode ? colors.slate[700] : colors.slate[50],
      controlItemBgActive: isDarkMode ? colors.primary[900] : colors.primary[50],
    },

    // Tag component
    Tag: {
      borderRadiusSM: 6,
    },

    // Tabs component
    Tabs: {
      itemSelectedColor: colors.primary[500],
      itemHoverColor: colors.primary[400],
      inkBarColor: colors.primary[500],
    },

    // Message component
    Message: {
      contentBg: isDarkMode ? colors.slate[800] : '#ffffff',
    },

    // Notification component
    Notification: {
      borderRadiusLG: 12,
    },

    // Statistic component
    Statistic: {
      titleFontSize: 14,
      contentFontSize: 24,
    },

    // Layout component
    Layout: {
      siderBg: isDarkMode ? colors.slate[950] : colors.slate[900],
      headerBg: isDarkMode ? colors.slate[900] : '#ffffff',
      bodyBg: isDarkMode ? colors.slate[900] : colors.slate[50],
    },

    // Breadcrumb component
    Breadcrumb: {
      itemColor: isDarkMode ? colors.slate[400] : colors.slate[500],
      lastItemColor: isDarkMode ? colors.slate[200] : colors.slate[700],
      linkColor: isDarkMode ? colors.slate[300] : colors.slate[600],
      linkHoverColor: colors.primary[500],
      separatorColor: isDarkMode ? colors.slate[600] : colors.slate[300],
    },

    // Tooltip component
    Tooltip: {
      colorBgSpotlight: isDarkMode ? colors.slate[700] : colors.slate[800],
    },

    // DatePicker component
    DatePicker: {
      borderRadius: 8,
      controlHeight: 40,
    },

    // Progress component
    Progress: {
      defaultColor: colors.primary[500],
    },

    // Spin component
    Spin: {
      colorPrimary: colors.primary[500],
    },
  },
});

export default createTheme;
