import React from 'react';
import { Typography, Spin, Empty } from 'antd';
import { UserOutlined, FileTextOutlined, ShopOutlined } from '@ant-design/icons';
import { useNavigate } from 'react-router-dom';
import './SearchDropdown.css';

const { Text } = Typography;

const SearchDropdown = ({ results, loading, query, onClose }) => {
  const navigate = useNavigate();

  // Handle navigation based on result type
  const handleResultClick = (result, type) => {
    switch (type) {
      case 'tenants':
        navigate('/tenants');
        break;
      case 'invoices':
        navigate(`/invoices`);
        break;
      case 'providers':
        navigate('/utility-providers');
        break;
      default:
        break;
    }
    onClose();
  };

  // Helper function to highlight matching text
  const highlightText = (text, searchQuery) => {
    if (!searchQuery || !text) return text;

    const regex = new RegExp(`(${searchQuery})`, 'gi');
    const parts = String(text).split(regex);

    return parts.map((part, index) =>
      regex.test(part) ? (
        <span key={index} className="highlight">
          {part}
        </span>
      ) : (
        part
      )
    );
  };

  // Get icon based on type
  const getIcon = (type) => {
    switch (type) {
      case 'tenants':
        return <UserOutlined style={{ fontSize: 16 }} />;
      case 'invoices':
        return <FileTextOutlined style={{ fontSize: 16 }} />;
      case 'providers':
        return <ShopOutlined style={{ fontSize: 16 }} />;
      default:
        return null;
    }
  };

  // Get category label
  const getCategoryLabel = (type) => {
    switch (type) {
      case 'tenants':
        return 'Chiriași';
      case 'invoices':
        return 'Facturi';
      case 'providers':
        return 'Furnizori';
      default:
        return type;
    }
  };

  // Get display name for an item
  const getItemName = (item, type) => {
    if (type === 'invoices') {
      return item.invoice_number || `Factură #${item.id}`;
    }
    return item.name;
  };

  // Get description for an item
  const getItemDescription = (item, type) => {
    switch (type) {
      case 'tenants':
        return item.email || item.phone || '';
      case 'invoices':
        return `${item.client_name || ''} - ${item.total_ron ? item.total_ron + ' RON' : ''}`;
      case 'providers':
        return item.account_number || '';
      default:
        return '';
    }
  };

  // Show loading state
  if (loading) {
    return (
      <div className="search-dropdown">
        <div style={{ textAlign: 'center', padding: '20px' }}>
          <Spin size="small" />
          <Text style={{ marginLeft: 8 }}>Căutare...</Text>
        </div>
      </div>
    );
  }

  // Show minimum characters message
  if (query.length < 2) {
    return (
      <div className="search-dropdown">
        <Empty
          image={Empty.PRESENTED_IMAGE_SIMPLE}
          description="Introduceți cel puțin 2 caractere pentru a căuta"
          style={{ padding: '20px' }}
        />
      </div>
    );
  }

  // Check if we have any results
  const hasResults = results && (
    (results.tenants && results.tenants.length > 0) ||
    (results.invoices && results.invoices.length > 0) ||
    (results.providers && results.providers.length > 0)
  );

  // Show no results message
  if (!hasResults) {
    return (
      <div className="search-dropdown">
        <Empty
          image={Empty.PRESENTED_IMAGE_SIMPLE}
          description="Nu au fost găsite rezultate"
          style={{ padding: '20px' }}
        />
      </div>
    );
  }

  // Categories to display
  const categories = [
    { key: 'tenants', items: results.tenants || [] },
    { key: 'invoices', items: results.invoices || [] },
    { key: 'providers', items: results.providers || [] },
  ].filter(cat => cat.items.length > 0);

  return (
    <div className="search-dropdown">
      {categories.map(({ key, items }) => (
        <div key={key} className="search-category">
          <div className="search-category-header">
            {getIcon(key)}
            <Text strong style={{ marginLeft: 8 }}>
              {getCategoryLabel(key)}
            </Text>
            <Text type="secondary" style={{ marginLeft: 8 }}>
              ({items.length})
            </Text>
          </div>
          <div className="search-results-list">
            {items.map((item) => (
              <div
                key={item.id}
                className="search-result-item"
                onClick={() => handleResultClick(item, key)}
              >
                <div className="search-result-content">
                  <div className="search-result-title">
                    {highlightText(getItemName(item, key), query)}
                  </div>
                  {getItemDescription(item, key) && (
                    <div className="search-result-description">
                      {highlightText(getItemDescription(item, key), query)}
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
};

export default SearchDropdown;
