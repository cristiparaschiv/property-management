import React from 'react';
import AnimatedCounter from './AnimatedCounter';
import '../../styles/components/cards.css';

/**
 * StatCard - Enhanced statistics card with animations
 * @param {string} title - Card title/label
 * @param {number|string} value - The main value to display
 * @param {string} prefix - Text/symbol before the value
 * @param {string} suffix - Text/symbol after the value
 * @param {React.ReactNode} icon - Icon to display
 * @param {string} secondary - Secondary text (shown at bottom)
 * @param {string} variant - Color variant: primary, success, warning, error, info
 * @param {function} formatter - Optional formatter for the value
 * @param {boolean} animate - Whether to animate the value
 * @param {number} decimals - Decimal places for animated numbers
 * @param {boolean} coloredValue - Whether to color the value
 * @param {function} onClick - Click handler
 */
const StatCard = ({
  title,
  value,
  prefix,
  suffix,
  icon,
  secondary,
  variant = 'primary',
  formatter,
  animate = true,
  decimals = 0,
  coloredValue = false,
  onClick,
}) => {
  const isNumeric = typeof value === 'number';

  return (
    <div
      className={`pm-stat-card pm-stat-card--${variant}`}
      onClick={onClick}
      style={onClick ? { cursor: 'pointer' } : undefined}
    >
      {icon && <div className="pm-stat-card__icon">{icon}</div>}
      <div className={`pm-stat-card__value ${coloredValue ? 'pm-stat-card__value--colored' : ''}`}>
        {prefix && <span>{prefix}</span>}
        {animate && isNumeric ? (
          <AnimatedCounter
            value={value}
            formatter={formatter}
            decimals={decimals}
          />
        ) : (
          formatter ? formatter(value) : value
        )}
        {suffix && <span style={{ fontSize: '0.6em', marginLeft: '4px' }}>{suffix}</span>}
      </div>
      <div className="pm-stat-card__label">{title}</div>
      {secondary && <div className="pm-stat-card__secondary">{secondary}</div>}
    </div>
  );
};

export default StatCard;
