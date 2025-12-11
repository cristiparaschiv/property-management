import React, { useState, useEffect, useRef } from 'react';
import { Layout, Menu, Button, Dropdown, Avatar, Input, Space, Switch, Tooltip } from 'antd';
import { Link, Outlet, useLocation, useNavigate } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import {
  DashboardOutlined,
  TeamOutlined,
  ShopOutlined,
  FileTextOutlined,
  ThunderboltOutlined,
  BarChartOutlined,
  CalculatorOutlined,
  ReconciliationOutlined,
  SettingOutlined,
  UserOutlined,
  LogoutOutlined,
  MenuFoldOutlined,
  MenuUnfoldOutlined,
  SearchOutlined,
  BulbOutlined,
  BulbFilled,
  KeyOutlined,
} from '@ant-design/icons';
import useAuthStore from '../stores/authStore';
import { useTheme } from '../contexts/ThemeContext';
import { searchService } from '../services/searchService';
import SearchDropdown from '../components/SearchDropdown';
import ChangePasswordModal from '../components/ChangePasswordModal';

const { Header, Sider, Content } = Layout;

const MainLayout = () => {
  const [collapsed, setCollapsed] = useState(false);
  const [searchValue, setSearchValue] = useState('');
  const [debouncedSearchValue, setDebouncedSearchValue] = useState('');
  const [showSearchDropdown, setShowSearchDropdown] = useState(false);
  const [changePasswordVisible, setChangePasswordVisible] = useState(false);
  const location = useLocation();
  const navigate = useNavigate();
  const { user, logout } = useAuthStore();
  const { isDarkMode, toggleTheme } = useTheme();
  const searchContainerRef = useRef(null);

  // Debounce search input
  useEffect(() => {
    const handler = setTimeout(() => {
      setDebouncedSearchValue(searchValue);
    }, 300);

    return () => {
      clearTimeout(handler);
    };
  }, [searchValue]);

  // Fetch search results using React Query
  const { data: searchResults, isLoading: isSearching } = useQuery({
    queryKey: ['search', debouncedSearchValue],
    queryFn: () => searchService.search(debouncedSearchValue),
    enabled: debouncedSearchValue.length >= 2,
    staleTime: 5000, // Cache results for 5 seconds
  });

  // Show/hide dropdown based on search value
  useEffect(() => {
    if (searchValue.length > 0) {
      setShowSearchDropdown(true);
    } else {
      setShowSearchDropdown(false);
    }
  }, [searchValue]);

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (event) => {
      if (searchContainerRef.current && !searchContainerRef.current.contains(event.target)) {
        setShowSearchDropdown(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  // Close dropdown on Escape key
  useEffect(() => {
    const handleEscapeKey = (event) => {
      if (event.key === 'Escape') {
        setShowSearchDropdown(false);
        setSearchValue('');
      }
    };

    document.addEventListener('keydown', handleEscapeKey);
    return () => {
      document.removeEventListener('keydown', handleEscapeKey);
    };
  }, []);

  const handleSearchChange = (e) => {
    setSearchValue(e.target.value);
  };

  const handleCloseDropdown = () => {
    setShowSearchDropdown(false);
    setSearchValue('');
  };

  const menuItems = [
    {
      key: '/',
      icon: <DashboardOutlined />,
      label: <Link to="/">Dashboard</Link>,
    },
    {
      key: '/tenants',
      icon: <TeamOutlined />,
      label: <Link to="/tenants">Chiriași</Link>,
    },
    {
      key: '/utility-providers',
      icon: <ShopOutlined />,
      label: <Link to="/utility-providers">Furnizori Utilități</Link>,
    },
    {
      key: '/received-invoices',
      icon: <FileTextOutlined />,
      label: <Link to="/received-invoices">Facturi Primite</Link>,
    },
    {
      key: '/meters',
      icon: <ThunderboltOutlined />,
      label: <Link to="/meters">Contoare</Link>,
    },
    {
      key: '/meter-readings',
      icon: <BarChartOutlined />,
      label: <Link to="/meter-readings">Indexuri Contoare</Link>,
    },
    {
      key: '/utility-calculations',
      icon: <CalculatorOutlined />,
      label: <Link to="/utility-calculations">Calcule Utilități</Link>,
    },
    {
      key: '/invoices',
      icon: <ReconciliationOutlined />,
      label: <Link to="/invoices">Facturi Emise</Link>,
    },
  ];

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const handleMenuClick = ({ key }) => {
    if (key === 'profile') {
      navigate('/profile');
    } else if (key === 'change-password') {
      setChangePasswordVisible(true);
    } else if (key === 'logout') {
      handleLogout();
    }
  };

  const userMenuItems = [
    {
      key: 'profile',
      icon: <UserOutlined />,
      label: 'Profilul meu',
    },
    {
      key: 'change-password',
      icon: <KeyOutlined />,
      label: 'Schimbă parola',
    },
    {
      type: 'divider',
    },
    {
      key: 'logout',
      icon: <LogoutOutlined />,
      label: 'Deconectare',
    },
  ];

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Sider
        trigger={null}
        collapsible
        collapsed={collapsed}
        width={250}
        style={{
          background: isDarkMode ? '#1f1f1f' : '#001529',
          transition: 'background-color 0.3s ease',
        }}
      >
        <div
          style={{
            height: 64,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: '#fff',
            fontSize: collapsed ? 18 : 20,
            fontWeight: 'bold',
            padding: '0 16px',
            transition: 'all 0.3s ease',
          }}
        >
          {collapsed ? 'PM' : 'PropertyManager'}
        </div>
        <Menu
          theme="dark"
          mode="inline"
          selectedKeys={[location.pathname]}
          items={menuItems}
          style={{
            background: isDarkMode ? '#1f1f1f' : '#001529',
            transition: 'background-color 0.3s ease',
          }}
        />
      </Sider>
      <Layout>
        <Header style={{ padding: '0 24px', background: isDarkMode ? '#141414' : '#fff', display: 'flex', alignItems: 'center', justifyContent: 'space-between', transition: 'background-color 0.3s ease' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
            <Button
              type="text"
              icon={collapsed ? <MenuUnfoldOutlined /> : <MenuFoldOutlined />}
              onClick={() => setCollapsed(!collapsed)}
              style={{ fontSize: '16px', width: 64, height: 64 }}
            />
            <div ref={searchContainerRef} style={{ position: 'relative', width: 300 }}>
              <Input
                placeholder="Căutare globală..."
                allowClear
                style={{ width: '100%' }}
                value={searchValue}
                onChange={handleSearchChange}
                prefix={<SearchOutlined />}
              />
              {showSearchDropdown && (
                <SearchDropdown
                  results={searchResults}
                  loading={isSearching}
                  query={searchValue}
                  onClose={handleCloseDropdown}
                />
              )}
            </div>
          </div>
          <Space size="middle">
            <Tooltip title={isDarkMode ? 'Mod Luminos' : 'Mod Întunecat'}>
              <Button
                type="text"
                icon={isDarkMode ? <BulbFilled style={{ color: '#faad14' }} /> : <BulbOutlined />}
                onClick={toggleTheme}
                style={{ fontSize: '18px' }}
              />
            </Tooltip>
            <Dropdown menu={{ items: userMenuItems, onClick: handleMenuClick }} placement="bottomRight">
              <div style={{ display: 'flex', alignItems: 'center', cursor: 'pointer' }}>
                <Avatar icon={<UserOutlined />} style={{ marginRight: 8 }} />
                <span>{user?.full_name || 'User'}</span>
              </div>
            </Dropdown>
          </Space>
        </Header>
        <Content style={{ margin: '24px 16px', padding: 24, background: isDarkMode ? '#141414' : '#fff', minHeight: 280, transition: 'background-color 0.3s ease' }}>
          <Outlet />
        </Content>
      </Layout>
      <ChangePasswordModal
        visible={changePasswordVisible}
        onClose={() => setChangePasswordVisible(false)}
      />
    </Layout>
  );
};

export default MainLayout;
