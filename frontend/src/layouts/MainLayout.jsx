import React, { useState, useEffect, useRef } from 'react';
import { Layout, Menu, Button, Dropdown, Avatar, Input, Tooltip } from 'antd';
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
  UserOutlined,
  LogoutOutlined,
  MenuFoldOutlined,
  MenuUnfoldOutlined,
  SearchOutlined,
  BulbOutlined,
  BulbFilled,
  KeyOutlined,
  CloudOutlined,
  PieChartOutlined,
} from '@ant-design/icons';
import useAuthStore from '../stores/authStore';
import { useTheme } from '../contexts/ThemeContext';
import { searchService } from '../services/searchService';
import SearchDropdown from '../components/SearchDropdown';
import ChangePasswordModal from '../components/ChangePasswordModal';
import NotificationBell from '../components/NotificationBell';
import '../styles/components/layout.css';

const { Header, Sider, Content } = Layout;

const MOBILE_BREAKPOINT = 768;
const TABLET_BREAKPOINT = 992;

const MainLayout = () => {
  const [collapsed, setCollapsed] = useState(false);
  const [isMobile, setIsMobile] = useState(window.innerWidth <= MOBILE_BREAKPOINT);
  const [isTablet, setIsTablet] = useState(window.innerWidth <= TABLET_BREAKPOINT && window.innerWidth > MOBILE_BREAKPOINT);
  const [searchValue, setSearchValue] = useState('');
  const [debouncedSearchValue, setDebouncedSearchValue] = useState('');
  const [showSearchDropdown, setShowSearchDropdown] = useState(false);
  const [changePasswordVisible, setChangePasswordVisible] = useState(false);
  const location = useLocation();
  const navigate = useNavigate();
  const { user, logout } = useAuthStore();
  const { isDarkMode, toggleTheme } = useTheme();
  const searchContainerRef = useRef(null);

  // Detect mobile/tablet viewport
  useEffect(() => {
    const handleResize = () => {
      const width = window.innerWidth;
      const wasMobile = isMobile;
      const newIsMobile = width <= MOBILE_BREAKPOINT;
      const newIsTablet = width <= TABLET_BREAKPOINT && width > MOBILE_BREAKPOINT;

      setIsMobile(newIsMobile);
      setIsTablet(newIsTablet);

      // Auto-collapse on mobile, expand on desktop
      if (newIsMobile && !wasMobile) {
        setCollapsed(true);
      } else if (!newIsMobile && wasMobile) {
        setCollapsed(false);
      }
    };

    // Initial check
    if (isMobile) {
      setCollapsed(true);
    }

    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, [isMobile]);

  // Close sidebar when navigating on mobile
  useEffect(() => {
    if (isMobile && !collapsed) {
      setCollapsed(true);
    }
  }, [location.pathname]);

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
    staleTime: 5000,
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
    {
      key: '/reports',
      icon: <PieChartOutlined />,
      label: <Link to="/reports">Rapoarte</Link>,
    },
    {
      type: 'divider',
    },
    {
      key: '/settings',
      icon: <CloudOutlined />,
      label: <Link to="/settings">Backup & Setări</Link>,
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
      danger: true,
    },
  ];

  // Get user initials for avatar
  const getUserInitials = () => {
    if (user?.full_name) {
      const names = user.full_name.split(' ');
      if (names.length >= 2) {
        return (names[0][0] + names[names.length - 1][0]).toUpperCase();
      }
      return names[0][0].toUpperCase();
    }
    return 'U';
  };

  const handleOverlayClick = () => {
    if (isMobile) {
      setCollapsed(true);
    }
  };

  const handleMenuItemClick = () => {
    if (isMobile) {
      setCollapsed(true);
    }
  };

  return (
    <Layout style={{ minHeight: '100vh' }}>
      {/* Mobile overlay */}
      {isMobile && (
        <div
          className={`pm-sidebar-overlay ${!collapsed ? 'pm-sidebar-overlay--visible' : ''}`}
          onClick={handleOverlayClick}
        />
      )}
      <Sider
        trigger={null}
        collapsible
        collapsed={collapsed}
        width={250}
        collapsedWidth={isMobile ? 0 : 80}
        className={`pm-sidebar ${collapsed ? 'pm-sidebar--collapsed' : ''} ${isMobile ? 'pm-sidebar--mobile' : ''}`}
      >
        <div className="pm-sidebar__logo">
          <img
            src="/assets/domistra-2-icon.png"
            alt="Domistra"
            className="pm-sidebar__logo-icon-img"
          />
          {!collapsed && <span className="pm-sidebar__logo-text">Domistra</span>}
        </div>
        <Menu
          theme="dark"
          mode="inline"
          selectedKeys={[location.pathname]}
          items={menuItems}
          className="pm-sidebar__menu"
          onClick={handleMenuItemClick}
        />
      </Sider>
      <Layout>
        <Header className="pm-header">
          <div className="pm-header__left">
            <Tooltip title={collapsed ? 'Extinde meniul' : 'Restrânge meniul'}>
              <Button
                type="text"
                icon={collapsed ? <MenuUnfoldOutlined /> : <MenuFoldOutlined />}
                onClick={() => setCollapsed(!collapsed)}
                className="pm-header__toggle"
              />
            </Tooltip>
            <div ref={searchContainerRef} className="pm-header__search">
              <Input
                placeholder="Căutare globală..."
                allowClear
                value={searchValue}
                onChange={handleSearchChange}
                prefix={<SearchOutlined style={{ color: 'var(--pm-color-text-tertiary)' }} />}
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
          <div className="pm-header__right">
            <NotificationBell />
            <Tooltip title={isDarkMode ? 'Mod Luminos' : 'Mod Întunecat'}>
              <Button
                type="text"
                icon={isDarkMode ? <BulbFilled /> : <BulbOutlined />}
                onClick={toggleTheme}
                className={`pm-header__action ${isDarkMode ? 'pm-header__action--theme' : ''}`}
              />
            </Tooltip>
            <Dropdown
              menu={{ items: userMenuItems, onClick: handleMenuClick }}
              placement="bottomRight"
              trigger={['click']}
            >
              <div className="pm-header__user">
                <div className="pm-header__user-avatar">
                  {getUserInitials()}
                </div>
                <div className="pm-header__user-info">
                  <span className="pm-header__user-name">{user?.full_name || 'User'}</span>
                  <span className="pm-header__user-role">Administrator</span>
                </div>
              </div>
            </Dropdown>
          </div>
        </Header>
        <Content className="pm-content">
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
