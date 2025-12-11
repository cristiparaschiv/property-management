import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ConfigProvider, theme as antdTheme } from 'antd';
import roRO from 'antd/locale/ro_RO';
import { ThemeProvider, useTheme } from './contexts/ThemeContext';
import MainLayout from './layouts/MainLayout';
import ProtectedRoute from './components/ProtectedRoute';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Profile from './pages/Profile';
import CompanySettings from './pages/CompanySettings';
import Tenants from './pages/Tenants';
import UtilityProviders from './pages/UtilityProviders';
import ReceivedInvoices from './pages/ReceivedInvoices';
import Meters from './pages/Meters';
import MeterReadings from './pages/MeterReadings';
import UtilityCalculations from './pages/UtilityCalculations';
import Invoices from './pages/Invoices';
import Reports from './pages/Reports';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: false,
      retry: 1,
    },
  },
});

function AppContent() {
  const { isDarkMode } = useTheme();

  return (
    <ConfigProvider
      locale={roRO}
      theme={{
        algorithm: isDarkMode ? antdTheme.darkAlgorithm : antdTheme.defaultAlgorithm,
        token: {
          colorPrimary: '#1890ff',
          borderRadius: 6,
        },
      }}
    >
      <Router>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route
            path="/"
            element={
              <ProtectedRoute>
                <MainLayout />
              </ProtectedRoute>
            }
          >
            <Route index element={<Dashboard />} />
            <Route path="profile" element={<Profile />} />
            <Route path="company" element={<CompanySettings />} />
            <Route path="tenants" element={<Tenants />} />
            <Route path="utility-providers" element={<UtilityProviders />} />
            <Route path="received-invoices" element={<ReceivedInvoices />} />
            <Route path="meters" element={<Meters />} />
            <Route path="meter-readings" element={<MeterReadings />} />
            <Route path="utility-calculations" element={<UtilityCalculations />} />
            <Route path="invoices" element={<Invoices />} />
            <Route path="reports" element={<Reports />} />
          </Route>
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </Router>
    </ConfigProvider>
  );
}

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <ThemeProvider>
        <AppContent />
      </ThemeProvider>
    </QueryClientProvider>
  );
}

export default App;
