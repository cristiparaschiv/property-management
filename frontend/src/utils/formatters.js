import dayjs from 'dayjs';
import 'dayjs/locale/ro';

dayjs.locale('ro');

/**
 * Format date to Romanian format DD.MM.YYYY
 * @param {string|Date|dayjs} date - Date to format
 * @returns {string} Formatted date
 */
export const formatDate = (date) => {
  if (!date) return '';
  return dayjs(date).format('DD.MM.YYYY');
};

/**
 * Format datetime to Romanian format DD.MM.YYYY HH:mm
 * @param {string|Date|dayjs} date - DateTime to format
 * @returns {string} Formatted datetime
 */
export const formatDateTime = (date) => {
  if (!date) return '';
  return dayjs(date).format('DD.MM.YYYY HH:mm');
};

/**
 * Format number to Romanian format: 1.234,56
 * @param {number} value - Number to format
 * @param {number} decimals - Number of decimal places (default: 2)
 * @returns {string} Formatted number
 */
export const formatNumber = (value, decimals = 2) => {
  if (value === null || value === undefined) return '';

  const num = Number(value);
  if (isNaN(num)) return '';

  return num.toLocaleString('ro-RO', {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  });
};

/**
 * Format currency in RON
 * @param {number} value - Amount to format
 * @returns {string} Formatted currency
 */
export const formatCurrency = (value) => {
  if (value === null || value === undefined) return '';

  const num = Number(value);
  if (isNaN(num)) return '';

  return num.toLocaleString('ro-RO', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }) + ' RON';
};

/**
 * Format currency in EUR
 * @param {number} value - Amount to format
 * @returns {string} Formatted currency
 */
export const formatEuro = (value) => {
  if (value === null || value === undefined) return '';

  const num = Number(value);
  if (isNaN(num)) return '';

  return num.toLocaleString('ro-RO', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }) + ' EUR';
};

/**
 * Parse Romanian formatted number to JavaScript number
 * @param {string} value - Romanian formatted number string (e.g., "1.234,56")
 * @returns {number} Parsed number
 */
export const parseRomanianNumber = (value) => {
  if (!value) return null;

  // Remove thousand separators (.)
  let cleaned = value.replace(/\./g, '');
  // Replace decimal comma with dot
  cleaned = cleaned.replace(',', '.');

  return parseFloat(cleaned);
};

/**
 * Format month name in Romanian
 * @param {number} month - Month number (1-12)
 * @returns {string} Month name in Romanian
 */
export const getMonthName = (month) => {
  const months = [
    'Ianuarie', 'Februarie', 'Martie', 'Aprilie', 'Mai', 'Iunie',
    'Iulie', 'August', 'Septembrie', 'Octombrie', 'Noiembrie', 'Decembrie'
  ];
  return months[month - 1] || '';
};
