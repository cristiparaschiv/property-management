import React from 'react';
import '../../styles/components/list-summary.css';

/**
 * ListSummaryCards - Container for summary cards on list pages
 */
export const ListSummaryCards = ({ children, className = '' }) => (
  <div className={`pm-list-summary ${className}`}>
    {children}
  </div>
);

/**
 * SummaryCard - Individual summary card for list page metrics
 * @param {React.ReactNode} icon - Icon to display
 * @param {string|number} value - The metric value
 * @param {string} label - Description label
 * @param {'default' | 'success' | 'warning' | 'error' | 'info'} variant - Color variant
 * @param {string} subValue - Optional secondary value
 * @param {function} onClick - Optional click handler
 */
export const SummaryCard = ({
  icon,
  value,
  label,
  variant = 'default',
  subValue,
  onClick,
}) => (
  <div
    className={`pm-summary-card pm-summary-card--${variant}`}
    onClick={onClick}
    style={onClick ? { cursor: 'pointer' } : undefined}
  >
    <div className="pm-summary-card__icon">{icon}</div>
    <div className="pm-summary-card__content">
      <div className="pm-summary-card__value">{value}</div>
      <div className="pm-summary-card__label">{label}</div>
      {subValue && <div className="pm-summary-card__subvalue">{subValue}</div>}
    </div>
  </div>
);

/**
 * ListPageHeader - Header for list pages with title, subtitle, and action button
 */
export const ListPageHeader = ({
  title,
  subtitle,
  action,
  className = '',
}) => (
  <div className={`pm-list-header ${className}`}>
    <div className="pm-list-header__text">
      <h1 className="pm-list-header__title">{title}</h1>
      {subtitle && <p className="pm-list-header__subtitle">{subtitle}</p>}
    </div>
    {action && <div className="pm-list-header__action">{action}</div>}
  </div>
);

/**
 * ListToolbar - Search and filter toolbar for list pages
 */
export const ListToolbar = ({
  children,
  className = '',
}) => (
  <div className={`pm-list-toolbar ${className}`}>
    {children}
  </div>
);

export default ListSummaryCards;
