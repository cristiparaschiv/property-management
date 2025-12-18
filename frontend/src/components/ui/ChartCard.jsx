import React from 'react';
import { Spin } from 'antd';
import { BarChartOutlined } from '@ant-design/icons';
import '../../styles/components/cards.css';

/**
 * ChartCard - Styled container for charts
 * @param {string} title - Card title
 * @param {string} subtitle - Optional subtitle
 * @param {React.ReactNode} children - Chart content
 * @param {React.ReactNode} actions - Optional action buttons
 * @param {boolean} loading - Loading state
 * @param {boolean} empty - Whether to show empty state
 * @param {string} emptyText - Text to show when empty
 * @param {number} height - Chart height
 * @param {boolean} noPadding - Remove body padding
 */
const ChartCard = ({
  title,
  subtitle,
  children,
  actions,
  loading = false,
  empty = false,
  emptyText = 'Nu există date disponibile',
  height = 300,
  noPadding = false,
}) => {
  const renderContent = () => {
    if (loading) {
      return (
        <div className="pm-card-loading" style={{ height }}>
          <Spin size="large" />
        </div>
      );
    }

    if (empty) {
      return (
        <div className="pm-chart-empty" style={{ height }}>
          <BarChartOutlined className="pm-chart-empty__icon" />
          <p className="pm-chart-empty__text">{emptyText}</p>
        </div>
      );
    }

    return children;
  };

  return (
    <div className="pm-chart-card">
      <div className="pm-chart-card__header">
        <div>
          <h3 className="pm-chart-card__title">{title}</h3>
          {subtitle && <p className="pm-chart-card__subtitle">{subtitle}</p>}
        </div>
        {actions && <div className="pm-chart-card__actions">{actions}</div>}
      </div>
      <div className={`pm-chart-card__body ${noPadding ? 'pm-chart-card__body--no-padding' : ''}`}>
        {renderContent()}
      </div>
    </div>
  );
};

export default ChartCard;
