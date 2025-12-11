import React from 'react';
import { Card, Row, Col, Statistic, Spin, Alert, Table, Tag, Button, Typography } from 'antd';
import {
  UserOutlined,
  FileTextOutlined,
  DollarOutlined,
  CreditCardOutlined,
  WarningOutlined,
  BankOutlined,
} from '@ant-design/icons';
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip, Legend, BarChart, Bar, XAxis, YAxis, CartesianGrid, LineChart, Line } from 'recharts';
import { dashboardService } from '../services/dashboardService';
import { formatCurrency, formatDate, getMonthName } from '../utils/formatters';
import { getUtilityTypeLabel } from '../constants/utilityTypes';

const { Title } = Typography;

// Colors for charts
const COLORS = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042', '#8884D8', '#82CA9D'];
const PIE_COLORS = {
  paid: '#52c41a',
  unpaid: '#ff4d4f',
};

const Dashboard = () => {
  // Fetch dashboard summary
  const { data: summaryData, isLoading: summaryLoading, error: summaryError } = useQuery({
    queryKey: ['dashboard-summary'],
    queryFn: dashboardService.getSummary,
  });

  // Fetch utility costs chart
  const { data: utilityCostsData, isLoading: utilityCostsLoading } = useQuery({
    queryKey: ['dashboard-utility-costs'],
    queryFn: () => dashboardService.getUtilityCostsChart(),
  });

  // Fetch expenses trend chart
  const { data: expensesTrendData, isLoading: expensesTrendLoading } = useQuery({
    queryKey: ['dashboard-expenses-trend'],
    queryFn: () => dashboardService.getExpensesTrendChart(6),
  });

  // Fetch invoices status chart
  const { data: invoicesStatusData, isLoading: invoicesStatusLoading } = useQuery({
    queryKey: ['dashboard-invoices-status'],
    queryFn: () => dashboardService.getInvoicesStatusChart(),
  });

  // Fetch cash flow chart
  const { data: cashFlowData, isLoading: cashFlowLoading } = useQuery({
    queryKey: ['dashboard-cash-flow'],
    queryFn: () => dashboardService.getCashFlowChart(12),
  });

  if (summaryLoading) {
    return (
      <div style={{ textAlign: 'center', padding: '50px' }}>
        <Spin size="large" />
      </div>
    );
  }

  if (summaryError) {
    return (
      <Alert
        title="Eroare"
        description="Nu s-au putut încărca datele dashboard-ului"
        type="error"
        showIcon
      />
    );
  }

  const summary = summaryData?.data || {};

  // Prepare utility costs data for pie chart
  const utilityChartData = utilityCostsData?.data?.map((item) => ({
    name: getUtilityTypeLabel(item.utility_type),
    value: parseFloat(item.amount),
  })) || [];

  // Prepare expenses trend data for bar chart
  const expensesChartData = expensesTrendData?.data?.map((item) => ({
    name: getMonthName(item.month),
    expenses: parseFloat(item.expenses),
  })) || [];

  // Prepare invoices status data for pie chart
  const invoicesStatusChartData = invoicesStatusData?.data ? [
    { name: 'Plătite', value: invoicesStatusData.data.paid.count, amount: parseFloat(invoicesStatusData.data.paid.total) },
    { name: 'Neplătite', value: invoicesStatusData.data.unpaid.count, amount: parseFloat(invoicesStatusData.data.unpaid.total) },
  ] : [];

  // Prepare cash flow data for line chart
  const cashFlowChartData = cashFlowData?.data?.map((item) => ({
    name: item.month_name || getMonthName(item.month),
    receivedPayments: parseFloat(item.received_payments || 0),
    invoicesIssued: parseFloat(item.invoices_issued || 0),
    paymentsMade: parseFloat(item.payments_made || 0),
    utilityInvoices: parseFloat(item.utility_invoices || 0),
  })) || [];

  // Columns for recent received invoices table
  const recentInvoicesColumns = [
    {
      title: 'Furnizor',
      dataIndex: 'provider_name',
      key: 'provider_name',
    },
    {
      title: 'Tip utilitate',
      dataIndex: 'utility_type',
      key: 'utility_type',
      render: (type) => getUtilityTypeLabel(type),
    },
    {
      title: 'Sumă',
      dataIndex: 'amount',
      key: 'amount',
      render: (amount) => formatCurrency(parseFloat(amount)),
    },
    {
      title: 'Perioadă',
      dataIndex: 'period_start',
      key: 'period_start',
      render: (date) => date ? formatDate(date) : '-',
    },
    {
      title: 'Status',
      dataIndex: 'is_paid',
      key: 'is_paid',
      render: (isPaid) => (
        <Tag color={isPaid ? 'green' : 'red'}>
          {isPaid ? 'Plătită' : 'Neplătită'}
        </Tag>
      ),
    },
  ];

  // Columns for upcoming due invoices table
  const upcomingDueColumns = [
    {
      title: 'Furnizor',
      dataIndex: 'provider_name',
      key: 'provider_name',
    },
    {
      title: 'Tip utilitate',
      dataIndex: 'utility_type',
      key: 'utility_type',
      render: (type) => getUtilityTypeLabel(type),
    },
    {
      title: 'Sumă',
      dataIndex: 'amount',
      key: 'amount',
      render: (amount) => formatCurrency(parseFloat(amount)),
    },
    {
      title: 'Scadență',
      dataIndex: 'due_date',
      key: 'due_date',
      render: (date) => date ? formatDate(date) : '-',
    },
  ];

  // Custom tooltip for pie charts
  const CustomTooltip = ({ active, payload }) => {
    if (active && payload && payload.length) {
      return (
        <div style={{
          backgroundColor: 'white',
          padding: '10px',
          border: '1px solid #ccc',
          borderRadius: '4px',
        }}>
          <p style={{ margin: 0 }}><strong>{payload[0].name}</strong></p>
          <p style={{ margin: 0 }}>Număr: {payload[0].value}</p>
          {payload[0].payload.amount && (
            <p style={{ margin: 0 }}>Sumă: {formatCurrency(payload[0].payload.amount)}</p>
          )}
        </div>
      );
    }
    return null;
  };

  return (
    <div>
      <Title level={2} style={{ marginBottom: 24 }}>Dashboard</Title>

      {/* KPI Widgets */}
      <Row gutter={[16, 16]}>
        <Col xs={24} sm={12} md={8} lg={8} xl={4} xxl={4}>
          <Card style={{ minHeight: '140px', display: 'flex', flexDirection: 'column' }}>
            <Statistic
              title="Chiriași Activi"
              value={summary.active_tenants || 0}
              prefix={<UserOutlined />}
              styles={{ value: { color: '#3f8600' } }}
            />
          </Card>
        </Col>

        <Col xs={24} sm={12} md={8} lg={8} xl={5} xxl={5}>
          <Card style={{ minHeight: '140px', display: 'flex', flexDirection: 'column' }}>
            <Statistic
              title="Sold Companie"
              value={parseFloat(summary.company_balance || 0)}
              prefix={<BankOutlined />}
              styles={{ value: { color: parseFloat(summary.company_balance || 0) >= 0 ? '#3f8600' : '#cf1322' } }}
              formatter={(value) => formatCurrency(value)}
            />
          </Card>
        </Col>

        <Col xs={24} sm={12} md={8} lg={8} xl={5} xxl={5}>
          <Card style={{ minHeight: '140px', display: 'flex', flexDirection: 'column' }}>
            <Statistic
              title="Facturi Neplătite"
              value={summary.unpaid_invoices?.count || 0}
              prefix={<FileTextOutlined />}
              styles={{ value: { color: summary.unpaid_invoices?.count > 0 ? '#cf1322' : '#3f8600' } }}
            />
            {summary.unpaid_invoices?.total && parseFloat(summary.unpaid_invoices.total) > 0 && (
              <div style={{ marginTop: 8, fontSize: '14px', color: '#666' }}>
                Total: {formatCurrency(parseFloat(summary.unpaid_invoices.total))}
              </div>
            )}
          </Card>
        </Col>

        <Col xs={24} sm={12} md={12} lg={12} xl={5} xxl={5}>
          <Card style={{ minHeight: '140px', display: 'flex', flexDirection: 'column' }}>
            <Statistic
              title="Cheltuieli Luna Curentă"
              value={parseFloat(summary.monthly_expenses || 0)}
              prefix={<CreditCardOutlined />}
              styles={{ value: { color: '#cf1322' } }}
              formatter={(value) => formatCurrency(value)}
            />
          </Card>
        </Col>

        <Col xs={24} sm={12} md={12} lg={12} xl={5} xxl={5}>
          <Card style={{ minHeight: '140px', display: 'flex', flexDirection: 'column' }}>
            <Statistic
              title="Chirie Totală Așteptată"
              value={parseFloat(summary.total_expected_rent || 0)}
              prefix={<DollarOutlined />}
              styles={{ value: { color: '#1890ff' } }}
              formatter={(value) => formatCurrency(value)}
            />
          </Card>
        </Col>
      </Row>

      {/* Charts Section */}
      <Row gutter={[16, 16]} style={{ marginTop: 24 }}>
        {/* Cash Flow Timeline */}
        <Col xs={24}>
          <Card title="Fluxul de Numerar - Istoric 12 Luni" style={{ height: '450px' }}>
            {cashFlowLoading ? (
              <div style={{ textAlign: 'center', padding: '50px' }}>
                <Spin />
              </div>
            ) : cashFlowChartData.length > 0 ? (
              <ResponsiveContainer width="100%" height={350}>
                <LineChart data={cashFlowChartData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis
                    dataKey="name"
                    label={{ value: 'Lună', position: 'insideBottom', offset: -5 }}
                  />
                  <YAxis
                    label={{ value: 'Valoare (RON)', angle: -90, position: 'insideLeft' }}
                  />
                  <Tooltip
                    formatter={(value) => {
                      const numValue = typeof value === 'number' ? value : parseFloat(value || 0);
                      return formatCurrency(numValue);
                    }}
                    labelStyle={{ color: '#000' }}
                  />
                  <Legend />
                  <Line
                    type="monotone"
                    dataKey="receivedPayments"
                    name="Plăți Primite"
                    stroke="#52c41a"
                    strokeWidth={2}
                    dot={{ r: 4 }}
                  />
                  <Line
                    type="monotone"
                    dataKey="invoicesIssued"
                    name="Facturi Emise"
                    stroke="#1890ff"
                    strokeWidth={2}
                    dot={{ r: 4 }}
                  />
                  <Line
                    type="monotone"
                    dataKey="paymentsMade"
                    name="Plăți Efectuate"
                    stroke="#ff4d4f"
                    strokeWidth={2}
                    dot={{ r: 4 }}
                  />
                  <Line
                    type="monotone"
                    dataKey="utilityInvoices"
                    name="Facturi Utilități"
                    stroke="#faad14"
                    strokeWidth={2}
                    dot={{ r: 4 }}
                  />
                </LineChart>
              </ResponsiveContainer>
            ) : (
              <div style={{
                textAlign: 'center',
                padding: '80px 20px',
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                gap: 12
              }}>
                <BarChartOutlined style={{ fontSize: 48, color: '#d9d9d9' }} />
                <div style={{ fontSize: 16, color: '#999' }}>
                  Nu există date de fluxul de numerar
                </div>
                <div style={{ fontSize: 14, color: '#bfbfbf' }}>
                  Datele vor apărea după ce începeți să emiteți facturi și să înregistrați plăți
                </div>
              </div>
            )}
          </Card>
        </Col>
      </Row>

      <Row gutter={[16, 16]} style={{ marginTop: 24 }}>
        {/* Expenses by Utility Type */}
        <Col xs={24} md={12} lg={8}>
          <Card title="Cheltuieli pe Tip Utilitate" style={{ height: '400px' }}>
            {utilityCostsLoading ? (
              <div style={{ textAlign: 'center', padding: '50px' }}>
                <Spin />
              </div>
            ) : utilityChartData.length > 0 ? (
              <ResponsiveContainer width="100%" height={300}>
                <PieChart>
                  <Pie
                    data={utilityChartData}
                    cx="50%"
                    cy="50%"
                    labelLine={false}
                    label={({ name, percent }) => `${name}: ${(percent * 100).toFixed(0)}%`}
                    outerRadius={80}
                    fill="#8884d8"
                    dataKey="value"
                  >
                    {utilityChartData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                    ))}
                  </Pie>
                  <Tooltip content={({ active, payload }) => {
                    if (active && payload && payload.length) {
                      return (
                        <div style={{
                          backgroundColor: 'white',
                          padding: '10px',
                          border: '1px solid #ccc',
                          borderRadius: '4px',
                        }}>
                          <p style={{ margin: 0 }}><strong>{payload[0].name}</strong></p>
                          <p style={{ margin: 0 }}>Sumă: {formatCurrency(payload[0].value)}</p>
                        </div>
                      );
                    }
                    return null;
                  }} />
                </PieChart>
              </ResponsiveContainer>
            ) : (
              <div style={{ textAlign: 'center', padding: '50px', color: '#999' }}>
                Nu există date disponibile
              </div>
            )}
          </Card>
        </Col>

        {/* Monthly Expenses Trend */}
        <Col xs={24} md={12} lg={8}>
          <Card title="Trend Cheltuieli (6 luni)" style={{ height: '400px' }}>
            {expensesTrendLoading ? (
              <div style={{ textAlign: 'center', padding: '50px' }}>
                <Spin />
              </div>
            ) : expensesChartData.length > 0 ? (
              <ResponsiveContainer width="100%" height={300}>
                <BarChart data={expensesChartData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="name" />
                  <YAxis />
                  <Tooltip
                    formatter={(value) => formatCurrency(value)}
                    labelStyle={{ color: '#000' }}
                  />
                  <Bar dataKey="expenses" fill="#ff4d4f" />
                </BarChart>
              </ResponsiveContainer>
            ) : (
              <div style={{ textAlign: 'center', padding: '50px', color: '#999' }}>
                Nu există date disponibile
              </div>
            )}
          </Card>
        </Col>

        {/* Invoices Status */}
        <Col xs={24} md={12} lg={8}>
          <Card title="Status Facturi" style={{ height: '400px' }}>
            {invoicesStatusLoading ? (
              <div style={{ textAlign: 'center', padding: '50px' }}>
                <Spin />
              </div>
            ) : invoicesStatusChartData.length > 0 && invoicesStatusChartData.some(d => d.value > 0) ? (
              <ResponsiveContainer width="100%" height={300}>
                <PieChart>
                  <Pie
                    data={invoicesStatusChartData}
                    cx="50%"
                    cy="50%"
                    labelLine={false}
                    label={({ name, percent }) => `${name}: ${(percent * 100).toFixed(0)}%`}
                    outerRadius={80}
                    fill="#8884d8"
                    dataKey="value"
                  >
                    {invoicesStatusChartData.map((entry, index) => (
                      <Cell
                        key={`cell-${index}`}
                        fill={entry.name === 'Plătite' ? PIE_COLORS.paid : PIE_COLORS.unpaid}
                      />
                    ))}
                  </Pie>
                  <Tooltip content={CustomTooltip} />
                  <Legend />
                </PieChart>
              </ResponsiveContainer>
            ) : (
              <div style={{ textAlign: 'center', padding: '50px', color: '#999' }}>
                Nu există date disponibile
              </div>
            )}
          </Card>
        </Col>
      </Row>

      {/* Recent Activity Section */}
      <Row gutter={[16, 16]} style={{ marginTop: 24 }}>
        {/* Recent Received Invoices */}
        <Col xs={24} lg={12}>
          <Card title="Facturi Primite Recente">
            {summary.recent_received_invoices && summary.recent_received_invoices.length > 0 ? (
              <Table
                columns={recentInvoicesColumns}
                dataSource={summary.recent_received_invoices}
                rowKey="id"
                pagination={false}
                size="small"
              />
            ) : (
              <div style={{ textAlign: 'center', padding: '20px', color: '#999' }}>
                Nu există facturi recente
              </div>
            )}
          </Card>
        </Col>

        {/* Upcoming Due Invoices */}
        <Col xs={24} lg={12}>
          <Card
            title={
              <span>
                <WarningOutlined style={{ color: '#faad14', marginRight: 8 }} />
                Facturi Cu Scadență Apropiată
              </span>
            }
          >
            {summary.upcoming_due_invoices && summary.upcoming_due_invoices.length > 0 ? (
              <Table
                columns={upcomingDueColumns}
                dataSource={summary.upcoming_due_invoices}
                rowKey="id"
                pagination={false}
                size="small"
              />
            ) : (
              <div style={{ textAlign: 'center', padding: '20px', color: '#999' }}>
                Nu există facturi cu scadență apropiată
              </div>
            )}
          </Card>
        </Col>
      </Row>

      {/* Quick Actions */}
      <Row gutter={[16, 16]} style={{ marginTop: 24 }}>
        <Col span={24}>
          <Card title="Acțiuni Rapide">
            <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap' }}>
              <Link to="/invoices">
                <Button type="primary">Creare Factură Nouă</Button>
              </Link>
              <Link to="/tenants">
                <Button>Gestionare Chiriași</Button>
              </Link>
              <Link to="/meter-readings">
                <Button>Adăugare Index Contor</Button>
              </Link>
              <Link to="/utility-calculations">
                <Button>Calcule Utilități</Button>
              </Link>
              <Link to="/received-invoices">
                <Button>Facturi Primite</Button>
              </Link>
            </div>
          </Card>
        </Col>
      </Row>
    </div>
  );
};

export default Dashboard;
