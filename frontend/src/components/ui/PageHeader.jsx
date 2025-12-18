import React from 'react';
import { Breadcrumb, Typography, Space } from 'antd';
import { Link, useLocation } from 'react-router-dom';
import { HomeOutlined } from '@ant-design/icons';

const { Title } = Typography;

// Romanian route labels
const routeLabels = {
  '/': 'Dashboard',
  '/tenants': 'Chiriași',
  '/utility-providers': 'Furnizori Utilități',
  '/received-invoices': 'Facturi Primite',
  '/meters': 'Contoare',
  '/meter-readings': 'Indexuri Contoare',
  '/utility-calculations': 'Calcule Utilități',
  '/invoices': 'Facturi Emise',
  '/reports': 'Rapoarte',
  '/profile': 'Profil',
  '/company': 'Setări Companie',
};

/**
 * PageHeader component with breadcrumb navigation
 * @param {string} title - Page title
 * @param {React.ReactNode} actions - Action buttons to display
 * @param {boolean} showBreadcrumb - Whether to show breadcrumb navigation
 * @param {string} subtitle - Optional subtitle text
 */
const PageHeader = ({
  title,
  actions,
  showBreadcrumb = true,
  subtitle,
}) => {
  const location = useLocation();
  const pathSegments = location.pathname.split('/').filter(Boolean);

  const breadcrumbItems = [
    {
      key: 'home',
      title: (
        <Link to="/" style={{ display: 'flex', alignItems: 'center' }}>
          <HomeOutlined />
        </Link>
      ),
    },
    ...pathSegments.map((segment, index) => {
      const path = '/' + pathSegments.slice(0, index + 1).join('/');
      const isLast = index === pathSegments.length - 1;
      const label = routeLabels[path] || segment.charAt(0).toUpperCase() + segment.slice(1).replace(/-/g, ' ');

      return {
        key: path,
        title: isLast ? (
          <span>{label}</span>
        ) : (
          <Link to={path}>{label}</Link>
        ),
      };
    }),
  ];

  return (
    <div className="pm-page-header">
      {showBreadcrumb && location.pathname !== '/' && (
        <div className="pm-page-header__breadcrumb">
          <Breadcrumb items={breadcrumbItems} />
        </div>
      )}
      <div className="pm-page-header__title-row">
        <div>
          <Title level={2} className="pm-page-header__title">
            {title}
          </Title>
          {subtitle && (
            <p style={{
              margin: '4px 0 0',
              color: 'var(--pm-color-text-secondary)',
              fontSize: 'var(--pm-font-size-sm)',
            }}>
              {subtitle}
            </p>
          )}
        </div>
        {actions && (
          <div className="pm-page-header__actions">
            <Space>{actions}</Space>
          </div>
        )}
      </div>
    </div>
  );
};

export default PageHeader;
