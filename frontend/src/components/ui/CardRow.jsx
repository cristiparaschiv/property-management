import React from 'react';
import { Tooltip } from 'antd';
import '../../styles/components/card-row.css';

/**
 * CardRow - Card-style row for list items with accent border
 * @param {React.ReactNode} children - Row content
 * @param {'default' | 'success' | 'warning' | 'error'} status - Status affects accent color
 * @param {function} onClick - Click handler for the content area
 * @param {React.ReactNode} actions - Action buttons to display on the right
 * @param {string} className - Additional CSS classes
 */
const CardRow = ({
  children,
  status = 'default',
  onClick,
  actions,
  className = '',
}) => {
  return (
    <div className={`pm-card-row pm-card-row--${status} ${className}`}>
      <div className="pm-card-row__accent" />
      <div
        className="pm-card-row__content"
        onClick={onClick}
        style={onClick ? { cursor: 'pointer' } : undefined}
      >
        {children}
      </div>
      {actions && (
        <div className="pm-card-row__actions">
          {actions}
        </div>
      )}
    </div>
  );
};

/**
 * CardRowPrimary - Primary line content (title, tags)
 */
export const CardRowPrimary = ({ children, className = '' }) => (
  <div className={`pm-card-row__primary ${className}`}>
    {children}
  </div>
);

/**
 * CardRowTitle - Title text within primary line
 */
export const CardRowTitle = ({ children, className = '' }) => (
  <span className={`pm-card-row__title ${className}`}>
    {children}
  </span>
);

/**
 * CardRowSecondary - Secondary line content (details, metadata)
 */
export const CardRowSecondary = ({ children, className = '' }) => (
  <div className={`pm-card-row__secondary ${className}`}>
    {children}
  </div>
);

/**
 * CardRowDetail - Individual detail item in secondary line
 */
export const CardRowDetail = ({ icon, children, className = '' }) => (
  <span className={`pm-card-row__detail ${className}`}>
    {icon && <span className="pm-card-row__detail-icon">{icon}</span>}
    {children}
  </span>
);

/**
 * ActionButton - Action button for card row with Tooltip
 */
export const ActionButton = ({
  icon,
  onClick,
  variant = 'default',
  title,
  disabled = false,
}) => {
  const button = (
    <button
      className={`pm-action-btn pm-action-btn--${variant}`}
      onClick={(e) => {
        e.stopPropagation();
        onClick?.(e);
      }}
      disabled={disabled}
      aria-label={title}
    >
      {icon}
    </button>
  );

  // Wrap with Tooltip if title is provided
  if (title) {
    return (
      <Tooltip title={title} placement="top">
        {button}
      </Tooltip>
    );
  }

  return button;
};

export default CardRow;
