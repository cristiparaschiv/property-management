import React from 'react';
import { Spin, Alert, Table, Tag, Button, Typography, Progress, Tooltip as AntTooltip } from 'antd';
import {
  UserOutlined,
  FileTextOutlined,
  DollarOutlined,
  CreditCardOutlined,
  WarningOutlined,
  BankOutlined,
  PlusOutlined,
  TeamOutlined,
  ThunderboltOutlined,
  CalculatorOutlined,
  FileSearchOutlined,
  HistoryOutlined,
  ExclamationCircleOutlined,
  ClockCircleOutlined,
} from '@ant-design/icons';
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import {
  PieChart,
  Pie,
  Cell,
  ResponsiveContainer,
  Tooltip,
  Legend,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Line,
  Area,
  AreaChart,
  LineChart,
} from 'recharts';
import { dashboardService } from '../services/dashboardService';
import { formatCurrency, formatEuro, formatDate, getMonthName } from '../utils/formatters';
import { getUtilityTypeLabel } from '../constants/utilityTypes';
import { useTheme } from '../contexts/ThemeContext';
import StatCard from '../components/ui/StatCard';
import ChartCard from '../components/ui/ChartCard';
import CollapsibleSection from '../components/ui/CollapsibleSection';
import ActivityLogWidget from '../components/ActivityLogWidget';
import '../styles/components/dashboard.css';
import '../styles/components/cards.css';

const { Title } = Typography;

const Dashboard = () => {
  const { isDarkMode, chartColors } = useTheme();

  // Chart colors based on theme
  const COLORS = chartColors?.palette || ['#10b981', '#3b82f6', '#f59e0b', '#ef4444', '#8b5cf6', '#06b6d4'];
  const PIE_COLORS = {
    paid: '#10b981',
    unpaid: '#ef4444',
  };

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

  // Fetch tenant balances
  const { data: tenantBalancesData, isLoading: tenantBalancesLoading } = useQuery({
    queryKey: ['dashboard-tenant-balances'],
    queryFn: dashboardService.getTenantBalances,
  });

  // Fetch overdue invoices
  const { data: overdueInvoicesData, isLoading: overdueLoading } = useQuery({
    queryKey: ['dashboard-overdue-invoices'],
    queryFn: dashboardService.getOverdueInvoices,
  });

  // Fetch utility evolution chart
  const { data: utilityEvolutionData, isLoading: utilityEvolutionLoading } = useQuery({
    queryKey: ['dashboard-utility-evolution'],
    queryFn: () => dashboardService.getUtilityEvolutionChart(12),
  });

  if (summaryLoading) {
    return (
      <div className="pm-card-loading" style={{ minHeight: '400px' }}>
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
  const utilityCostsRaw = utilityCostsData?.data;
  const utilityChartData = Array.isArray(utilityCostsRaw)
    ? utilityCostsRaw.map((item) => ({
        name: getUtilityTypeLabel(item.utility_type),
        value: parseFloat(item.amount),
      }))
    : [];

  // Prepare expenses trend data for bar chart
  const expensesTrendRaw = expensesTrendData?.data;
  const expensesChartData = Array.isArray(expensesTrendRaw)
    ? expensesTrendRaw.map((item) => ({
        name: getMonthName(item.month),
        expenses: parseFloat(item.expenses),
      }))
    : [];

  // Prepare invoices status data for pie chart
  const invoicesStatusChartData = invoicesStatusData?.data?.paid && invoicesStatusData?.data?.unpaid
    ? [
        { name: 'Plătite', value: invoicesStatusData.data.paid.count, amount: parseFloat(invoicesStatusData.data.paid.total) },
        { name: 'Neplătite', value: invoicesStatusData.data.unpaid.count, amount: parseFloat(invoicesStatusData.data.unpaid.total) },
      ]
    : [];

  // Prepare cash flow data for line chart
  const cashFlowRaw = cashFlowData?.data;
  const cashFlowChartData = Array.isArray(cashFlowRaw)
    ? cashFlowRaw.map((item) => ({
        name: item.month_name || getMonthName(item.month),
        receivedPayments: parseFloat(item.received_payments || 0),
        invoicesIssued: parseFloat(item.invoices_issued || 0),
        paymentsMade: parseFloat(item.payments_made || 0),
        utilityInvoices: parseFloat(item.utility_invoices || 0),
      }))
    : [];

  // Prepare tenant balances data
  const tenantBalancesRaw = tenantBalancesData?.data?.tenants;
  const tenantBalances = Array.isArray(tenantBalancesRaw) ? tenantBalancesRaw : [];
  const balancesSummary = tenantBalancesData?.data?.summary || {};

  // Prepare overdue invoices data
  const overdueInvoicesRaw = overdueInvoicesData?.data?.invoices;
  const overdueInvoices = Array.isArray(overdueInvoicesRaw) ? overdueInvoicesRaw : [];
  const overdueSummary = overdueInvoicesData?.data || {};
  const agingSummary = overdueSummary.aging_summary && typeof overdueSummary.aging_summary === 'object'
    ? Object.entries(overdueSummary.aging_summary)
    : [];

  // Prepare utility evolution data
  const utilityEvolutionRaw = utilityEvolutionData?.data;
  const utilityEvolutionChartData = Array.isArray(utilityEvolutionRaw)
    ? utilityEvolutionRaw.map((item) => ({
        name: item.month,
        electricity: parseFloat(item.electricity || 0),
        gas: parseFloat(item.gas || 0),
        water: parseFloat(item.water || 0),
        internet: parseFloat(item.internet || 0),
        salubrity: parseFloat(item.salubrity || 0),
        total: parseFloat(item.total || 0),
      }))
    : [];

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
        <Tag color={isPaid ? 'success' : 'error'}>
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

  // Columns for tenant balances table
  const tenantBalanceColumns = [
    {
      title: 'Chiriaș',
      dataIndex: 'tenant_name',
      key: 'tenant_name',
      render: (name, record) => (
        <Link to={`/tenants?id=${record.tenant_id}`}>{name}</Link>
      ),
    },
    {
      title: 'Total Facturat',
      dataIndex: 'total_invoiced',
      key: 'total_invoiced',
      render: (amount) => formatCurrency(parseFloat(amount)),
      align: 'right',
    },
    {
      title: 'Total Plătit',
      dataIndex: 'total_paid',
      key: 'total_paid',
      render: (amount) => formatCurrency(parseFloat(amount)),
      align: 'right',
    },
    {
      title: 'Sold',
      dataIndex: 'balance',
      key: 'balance',
      render: (balance) => {
        const value = parseFloat(balance);
        return (
          <span style={{ color: value > 0 ? 'var(--pm-color-error)' : 'var(--pm-color-success)', fontWeight: 600 }}>
            {formatCurrency(value)}
          </span>
        );
      },
      align: 'right',
    },
    {
      title: 'Facturi Neplătite',
      dataIndex: 'unpaid_count',
      key: 'unpaid_count',
      render: (count) => count > 0 ? (
        <Tag color="error">{count}</Tag>
      ) : (
        <Tag color="success">0</Tag>
      ),
      align: 'center',
    },
  ];

  // Columns for overdue invoices table
  const overdueColumns = [
    {
      title: 'Chiriaș',
      dataIndex: 'tenant_name',
      key: 'tenant_name',
      render: (name, record) => (
        <Link to={`/invoices?id=${record.id}`}>{name}</Link>
      ),
    },
    {
      title: 'Factură',
      dataIndex: 'invoice_number',
      key: 'invoice_number',
    },
    {
      title: 'Sumă',
      dataIndex: 'total_ron',
      key: 'total_ron',
      render: (amount) => formatCurrency(parseFloat(amount)),
      align: 'right',
    },
    {
      title: 'Scadență',
      dataIndex: 'due_date',
      key: 'due_date',
      render: (date) => formatDate(date),
    },
    {
      title: 'Zile Întârziere',
      dataIndex: 'days_overdue',
      key: 'days_overdue',
      render: (days, record) => {
        const color = record.aging_bucket === '90+' ? 'red' :
                     record.aging_bucket === '61-90' ? 'orange' :
                     record.aging_bucket === '31-60' ? 'gold' : 'volcano';
        return (
          <AntTooltip title={`Interval: ${record.aging_bucket} zile`}>
            <Tag color={color} icon={<ClockCircleOutlined />}>
              {days} zile
            </Tag>
          </AntTooltip>
        );
      },
      align: 'center',
    },
  ];

  // Custom tooltip component
  const CustomChartTooltip = ({ active, payload, label }) => {
    if (active && payload && payload.length) {
      return (
        <div className="pm-chart-tooltip">
          <p className="pm-chart-tooltip__label">{label}</p>
          {payload.map((entry, index) => (
            <div key={index} className="pm-chart-tooltip__item">
              <span
                className="pm-chart-tooltip__dot"
                style={{ backgroundColor: entry.color }}
              />
              <span>{entry.name}: {formatCurrency(entry.value)}</span>
            </div>
          ))}
        </div>
      );
    }
    return null;
  };

  // Custom pie tooltip
  const CustomPieTooltip = ({ active, payload }) => {
    if (active && payload && payload.length) {
      return (
        <div className="pm-chart-tooltip">
          <p className="pm-chart-tooltip__label">{payload[0].name}</p>
          <div className="pm-chart-tooltip__item">
            <span>Număr: {payload[0].value}</span>
          </div>
          {payload[0].payload.amount !== undefined && (
            <div className="pm-chart-tooltip__item">
              <span>Sumă: {formatCurrency(payload[0].payload.amount)}</span>
            </div>
          )}
        </div>
      );
    }
    return null;
  };

  const companyBalance = parseFloat(summary.company_balance || 0);
  const unpaidCount = summary.unpaid_invoices?.count || 0;

  return (
    <div className="pm-dashboard">
      {/* Dashboard Header */}
      <div className="pm-dashboard__header">
        <Title level={2} className="pm-dashboard__title">Dashboard</Title>
        <p className="pm-dashboard__subtitle">
          Vizualizare generală a proprietăților și finanțelor
        </p>
      </div>

      {/* KPI Stats */}
      <div className="pm-dashboard__stats">
        <StatCard
          title="Chiriași Activi"
          value={summary.active_tenants || 0}
          icon={<UserOutlined />}
          variant="success"
        />

        <StatCard
          title="Sold Companie"
          value={companyBalance}
          icon={<BankOutlined />}
          variant={companyBalance >= 0 ? 'success' : 'error'}
          formatter={(val) => formatCurrency(val)}
          decimals={2}
          coloredValue
        />

        <StatCard
          title="Facturi Neplătite"
          value={unpaidCount}
          icon={<FileTextOutlined />}
          variant={unpaidCount > 0 ? 'error' : 'success'}
          secondary={summary.unpaid_invoices?.total && parseFloat(summary.unpaid_invoices.total) > 0
            ? `Total: ${formatCurrency(parseFloat(summary.unpaid_invoices.total))}`
            : null
          }
        />

        <StatCard
          title="Cheltuieli Luna Curentă"
          value={parseFloat(summary.monthly_expenses || 0)}
          icon={<CreditCardOutlined />}
          variant="warning"
          formatter={(val) => formatCurrency(val)}
          decimals={2}
        />

        <StatCard
          title="Chirie Totală Așteptată"
          value={parseFloat(summary.total_expected_rent || 0)}
          icon={<DollarOutlined />}
          variant="info"
          formatter={(val) => formatEuro(val)}
          decimals={2}
        />
      </div>

      {/* Cash Flow Chart - Full Width */}
      <CollapsibleSection
        title="Fluxul de Numerar"
        icon={<DollarOutlined />}
        storageKey="dashboard-cash-flow"
      >
        <div className="pm-dashboard__charts" style={{ marginBottom: 'var(--pm-space-lg)' }}>
          <div className="pm-dashboard__chart--full">
            <ChartCard
              subtitle="Istoric 12 Luni"
              loading={cashFlowLoading}
              empty={!cashFlowChartData.length}
              emptyText="Datele vor apărea după ce începeți să emiteți facturi și să înregistrați plăți"
              height={350}
            >
              <ResponsiveContainer width="100%" height={350}>
                <AreaChart data={cashFlowChartData}>
                  <defs>
                    <linearGradient id="colorReceived" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#10b981" stopOpacity={0.3}/>
                      <stop offset="95%" stopColor="#10b981" stopOpacity={0}/>
                    </linearGradient>
                    <linearGradient id="colorIssued" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.3}/>
                      <stop offset="95%" stopColor="#3b82f6" stopOpacity={0}/>
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke={isDarkMode ? '#334155' : '#e2e8f0'} />
                  <XAxis
                    dataKey="name"
                    tick={{ fill: isDarkMode ? '#94a3b8' : '#64748b', fontSize: 12 }}
                    axisLine={{ stroke: isDarkMode ? '#334155' : '#e2e8f0' }}
                  />
                  <YAxis
                    tick={{ fill: isDarkMode ? '#94a3b8' : '#64748b', fontSize: 12 }}
                    axisLine={{ stroke: isDarkMode ? '#334155' : '#e2e8f0' }}
                    tickFormatter={(value) => `${(value / 1000).toFixed(0)}k`}
                  />
                  <Tooltip content={<CustomChartTooltip />} />
                  <Legend
                    wrapperStyle={{ paddingTop: '20px' }}
                    iconType="circle"
                  />
                  <Area
                    type="monotone"
                    dataKey="receivedPayments"
                    name="Plăți Primite"
                    stroke="#10b981"
                    strokeWidth={2}
                    fill="url(#colorReceived)"
                  />
                  <Area
                    type="monotone"
                    dataKey="invoicesIssued"
                    name="Facturi Emise"
                    stroke="#3b82f6"
                    strokeWidth={2}
                    fill="url(#colorIssued)"
                  />
                  <Line
                    type="monotone"
                    dataKey="paymentsMade"
                    name="Plăți Efectuate"
                    stroke="#ef4444"
                    strokeWidth={2}
                    dot={{ r: 3, fill: '#ef4444' }}
                  />
                  <Line
                    type="monotone"
                    dataKey="utilityInvoices"
                    name="Facturi Utilități"
                    stroke="#f59e0b"
                    strokeWidth={2}
                    dot={{ r: 3, fill: '#f59e0b' }}
                  />
                </AreaChart>
              </ResponsiveContainer>
            </ChartCard>
          </div>
        </div>
      </CollapsibleSection>

      {/* Utility Cost Evolution Chart - Full Width */}
      <CollapsibleSection
        title="Evoluție Costuri Utilități"
        icon={<ThunderboltOutlined />}
        storageKey="dashboard-utility-evolution"
      >
        <div className="pm-dashboard__charts" style={{ marginBottom: 'var(--pm-space-lg)' }}>
          <div className="pm-dashboard__chart--full">
            <ChartCard
              subtitle="Istoric 12 Luni pe Tip Utilitate"
              loading={utilityEvolutionLoading}
              empty={!utilityEvolutionChartData.length}
              emptyText="Datele vor apărea după ce înregistrați facturi de utilități"
              height={350}
            >
              <ResponsiveContainer width="100%" height={350}>
                <LineChart data={utilityEvolutionChartData}>
                  <CartesianGrid strokeDasharray="3 3" stroke={isDarkMode ? '#334155' : '#e2e8f0'} />
                  <XAxis
                    dataKey="name"
                    tick={{ fill: isDarkMode ? '#94a3b8' : '#64748b', fontSize: 11 }}
                    axisLine={{ stroke: isDarkMode ? '#334155' : '#e2e8f0' }}
                    interval={0}
                    angle={-45}
                    textAnchor="end"
                    height={60}
                  />
                  <YAxis
                    tick={{ fill: isDarkMode ? '#94a3b8' : '#64748b', fontSize: 12 }}
                    axisLine={{ stroke: isDarkMode ? '#334155' : '#e2e8f0' }}
                    tickFormatter={(value) => `${(value / 1000).toFixed(0)}k`}
                  />
                  <Tooltip content={<CustomChartTooltip />} />
                  <Legend
                    wrapperStyle={{ paddingTop: '20px' }}
                    iconType="circle"
                  />
                  <Line
                    type="monotone"
                    dataKey="electricity"
                    name="Electricitate"
                    stroke="#f59e0b"
                    strokeWidth={2}
                    dot={{ r: 3, fill: '#f59e0b' }}
                  />
                  <Line
                    type="monotone"
                    dataKey="gas"
                    name="Gaz"
                    stroke="#ef4444"
                    strokeWidth={2}
                    dot={{ r: 3, fill: '#ef4444' }}
                  />
                  <Line
                    type="monotone"
                    dataKey="water"
                    name="Apă"
                    stroke="#3b82f6"
                    strokeWidth={2}
                    dot={{ r: 3, fill: '#3b82f6' }}
                  />
                  <Line
                    type="monotone"
                    dataKey="internet"
                    name="Internet"
                    stroke="#8b5cf6"
                    strokeWidth={2}
                    dot={{ r: 3, fill: '#8b5cf6' }}
                  />
                  <Line
                    type="monotone"
                    dataKey="salubrity"
                    name="Salubritate"
                    stroke="#06b6d4"
                    strokeWidth={2}
                    dot={{ r: 3, fill: '#06b6d4' }}
                  />
                  <Line
                    type="monotone"
                    dataKey="total"
                    name="Total"
                    stroke="#10b981"
                    strokeWidth={3}
                    dot={{ r: 4, fill: '#10b981' }}
                    strokeDasharray="5 5"
                  />
                </LineChart>
              </ResponsiveContainer>
            </ChartCard>
          </div>
        </div>
      </CollapsibleSection>

      {/* Secondary Charts */}
      <CollapsibleSection
        title="Grafice Sumar"
        icon={<FileTextOutlined />}
        storageKey="dashboard-summary-charts"
      >
        <div className="pm-dashboard__charts">
          {/* Expenses by Utility Type */}
          <ChartCard
            title="Cheltuieli pe Tip Utilitate"
            subtitle="Distribuție curentă"
            loading={utilityCostsLoading}
            empty={!utilityChartData.length}
            height={280}
          >
          <ResponsiveContainer width="100%" height={280}>
            <PieChart>
              <Pie
                data={utilityChartData}
                cx="50%"
                cy="50%"
                innerRadius={50}
                outerRadius={90}
                paddingAngle={2}
                dataKey="value"
                nameKey="name"
              >
                {utilityChartData.map((entry, index) => (
                  <Cell
                    key={`cell-${index}`}
                    fill={COLORS[index % COLORS.length]}
                    stroke={isDarkMode ? '#1e293b' : '#ffffff'}
                    strokeWidth={2}
                  />
                ))}
              </Pie>
              <Tooltip content={({ active, payload }) => {
                if (active && payload && payload.length) {
                  return (
                    <div className="pm-chart-tooltip">
                      <p className="pm-chart-tooltip__label">{payload[0].name}</p>
                      <div className="pm-chart-tooltip__item">
                        <span>Sumă: {formatCurrency(payload[0].value)}</span>
                      </div>
                    </div>
                  );
                }
                return null;
              }} />
              <Legend
                verticalAlign="bottom"
                iconType="circle"
                formatter={(value) => <span style={{ color: isDarkMode ? '#cbd5e1' : '#475569' }}>{value}</span>}
              />
            </PieChart>
          </ResponsiveContainer>
        </ChartCard>

        {/* Monthly Expenses Trend */}
        <ChartCard
          title="Trend Cheltuieli"
          subtitle="Ultimele 6 luni"
          loading={expensesTrendLoading}
          empty={!expensesChartData.length}
          height={280}
        >
          <ResponsiveContainer width="100%" height={280}>
            <BarChart data={expensesChartData}>
              <defs>
                <linearGradient id="barGradient" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#ef4444" stopOpacity={1}/>
                  <stop offset="100%" stopColor="#ef4444" stopOpacity={0.6}/>
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke={isDarkMode ? '#334155' : '#e2e8f0'} />
              <XAxis
                dataKey="name"
                tick={{ fill: isDarkMode ? '#94a3b8' : '#64748b', fontSize: 12 }}
                axisLine={{ stroke: isDarkMode ? '#334155' : '#e2e8f0' }}
              />
              <YAxis
                tick={{ fill: isDarkMode ? '#94a3b8' : '#64748b', fontSize: 12 }}
                axisLine={{ stroke: isDarkMode ? '#334155' : '#e2e8f0' }}
              />
              <Tooltip content={<CustomChartTooltip />} />
              <Bar
                dataKey="expenses"
                name="Cheltuieli"
                fill="url(#barGradient)"
                radius={[4, 4, 0, 0]}
              />
            </BarChart>
          </ResponsiveContainer>
        </ChartCard>

        {/* Invoices Status */}
        <ChartCard
          title="Status Facturi"
          subtitle="Plătite vs Neplătite"
          loading={invoicesStatusLoading}
          empty={!invoicesStatusChartData.length || !invoicesStatusChartData.some(d => d.value > 0)}
          height={280}
        >
          <ResponsiveContainer width="100%" height={280}>
            <PieChart>
              <Pie
                data={invoicesStatusChartData}
                cx="50%"
                cy="50%"
                innerRadius={50}
                outerRadius={90}
                paddingAngle={2}
                dataKey="value"
                nameKey="name"
              >
                {invoicesStatusChartData.map((entry, index) => (
                  <Cell
                    key={`cell-${index}`}
                    fill={entry.name === 'Plătite' ? PIE_COLORS.paid : PIE_COLORS.unpaid}
                    stroke={isDarkMode ? '#1e293b' : '#ffffff'}
                    strokeWidth={2}
                  />
                ))}
              </Pie>
              <Tooltip content={<CustomPieTooltip />} />
              <Legend
                verticalAlign="bottom"
                iconType="circle"
                formatter={(value) => <span style={{ color: isDarkMode ? '#cbd5e1' : '#475569' }}>{value}</span>}
              />
            </PieChart>
          </ResponsiveContainer>
        </ChartCard>
        </div>
      </CollapsibleSection>

      {/* Tenant Balances & Overdue Invoices Section */}
      <CollapsibleSection
        title="Situație Financiară Chiriași"
        icon={<DollarOutlined />}
        storageKey="dashboard-tenant-finances"
      >
        <div className="pm-dashboard__tables">
        {/* Tenant Balances */}
        <ChartCard
          title={
            <span>
              <BankOutlined style={{ color: 'var(--pm-color-primary)', marginRight: 8 }} />
              Balanță Chiriași
            </span>
          }
          loading={tenantBalancesLoading}
          empty={!tenantBalances.length}
          emptyText="Nu există chiriași activi"
        >
          {balancesSummary.total_receivable && parseFloat(balancesSummary.total_receivable) > 0 && (
            <div style={{
              padding: 'var(--pm-space-sm) var(--pm-space-md)',
              marginBottom: 'var(--pm-space-md)',
              background: 'var(--pm-color-error-light)',
              borderRadius: 'var(--pm-radius-md)',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center'
            }}>
              <span style={{ color: 'var(--pm-color-error-dark)', fontWeight: 500 }}>
                <ExclamationCircleOutlined style={{ marginRight: 8 }} />
                Total de Încasat
              </span>
              <span style={{ color: 'var(--pm-color-error)', fontWeight: 700, fontSize: '1.1em' }}>
                {formatCurrency(parseFloat(balancesSummary.total_receivable))}
              </span>
            </div>
          )}
          <Table
            columns={tenantBalanceColumns}
            dataSource={tenantBalances.filter(t => parseFloat(t.balance) !== 0 || t.unpaid_count > 0)}
            rowKey="tenant_id"
            pagination={false}
            size="small"
            className="pm-dashboard__recent-table"
            locale={{ emptyText: 'Toți chiriașii sunt la zi' }}
          />
        </ChartCard>

        {/* Overdue Invoices */}
        <ChartCard
          title={
            <span>
              <ExclamationCircleOutlined style={{ color: 'var(--pm-color-error)', marginRight: 8 }} />
              Facturi Restante
            </span>
          }
          loading={overdueLoading}
          empty={!overdueInvoices.length}
          emptyText="Nu există facturi restante"
        >
          {overdueSummary.total_overdue && parseFloat(overdueSummary.total_overdue) > 0 && (
            <div style={{
              padding: 'var(--pm-space-sm) var(--pm-space-md)',
              marginBottom: 'var(--pm-space-md)',
              background: 'var(--pm-color-error-light)',
              borderRadius: 'var(--pm-radius-md)',
            }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 'var(--pm-space-xs)' }}>
                <span style={{ color: 'var(--pm-color-error-dark)', fontWeight: 500 }}>
                  Total Restant ({overdueSummary.count} facturi)
                </span>
                <span style={{ color: 'var(--pm-color-error)', fontWeight: 700, fontSize: '1.1em' }}>
                  {formatCurrency(parseFloat(overdueSummary.total_overdue))}
                </span>
              </div>
              {agingSummary.length > 0 && (
                <div style={{ display: 'flex', gap: 'var(--pm-space-sm)', flexWrap: 'wrap', marginTop: 'var(--pm-space-xs)' }}>
                  {agingSummary.map(([bucket, data]) => (
                    <Tag key={bucket} color={bucket === '90+' ? 'red' : bucket === '61-90' ? 'orange' : bucket === '31-60' ? 'gold' : 'volcano'}>
                      {bucket} zile: {data.count}
                    </Tag>
                  ))}
                </div>
              )}
            </div>
          )}
          <Table
            columns={overdueColumns}
            dataSource={overdueInvoices.slice(0, 10)}
            rowKey="id"
            pagination={false}
            size="small"
            className="pm-dashboard__recent-table"
          />
          {overdueInvoices.length > 10 && (
            <div style={{ textAlign: 'center', marginTop: 'var(--pm-space-md)' }}>
              <Link to="/reports?tab=overdue">
                <Button type="link">Vezi toate ({overdueInvoices.length})</Button>
              </Link>
            </div>
          )}
        </ChartCard>
        </div>
      </CollapsibleSection>

      {/* Recent Activity Tables */}
      <CollapsibleSection
        title="Facturi Recente"
        icon={<FileSearchOutlined />}
        storageKey="dashboard-recent-invoices"
      >
        <div className="pm-dashboard__tables">
          {/* Recent Received Invoices */}
          <ChartCard
            title="Facturi Primite Recente"
            empty={!Array.isArray(summary.recent_received_invoices) || !summary.recent_received_invoices.length}
            emptyText="Nu există facturi recente"
          >
            <Table
              columns={recentInvoicesColumns}
              dataSource={Array.isArray(summary.recent_received_invoices) ? summary.recent_received_invoices : []}
              rowKey="id"
              pagination={false}
              size="small"
              className="pm-dashboard__recent-table"
            />
          </ChartCard>

          {/* Upcoming Due Invoices */}
          <ChartCard
            title={
              <span>
                <WarningOutlined style={{ color: 'var(--pm-color-warning)', marginRight: 8 }} />
                Facturi Cu Scadență Apropiată
              </span>
            }
            empty={!Array.isArray(summary.upcoming_due_invoices) || !summary.upcoming_due_invoices.length}
            emptyText="Nu există facturi cu scadență apropiată"
          >
            <Table
              columns={upcomingDueColumns}
              dataSource={Array.isArray(summary.upcoming_due_invoices) ? summary.upcoming_due_invoices : []}
              rowKey="id"
              pagination={false}
              size="small"
              className="pm-dashboard__recent-table"
            />
          </ChartCard>
        </div>
      </CollapsibleSection>

      {/* Activity Log */}
      <CollapsibleSection
        title="Activitate Recentă"
        icon={<HistoryOutlined />}
        storageKey="dashboard-activity-log"
      >
        <div className="pm-dashboard__activity-section">
          <div className="pm-activity-log-card">
            <div className="pm-activity-log-card__content">
              <ActivityLogWidget limit={10} />
            </div>
          </div>
        </div>
      </CollapsibleSection>

      {/* Quick Actions */}
      <CollapsibleSection
        title="Acțiuni Rapide"
        icon={<PlusOutlined />}
        storageKey="dashboard-quick-actions"
      >
      <div className="pm-dashboard__actions">
        <Link to="/invoices">
          <Button type="primary" icon={<PlusOutlined />}>
            Creare Factură Nouă
          </Button>
        </Link>
        <Link to="/tenants">
          <Button icon={<TeamOutlined />}>
            Gestionare Chiriași
          </Button>
        </Link>
        <Link to="/meter-readings">
          <Button icon={<ThunderboltOutlined />}>
            Adăugare Index Contor
          </Button>
        </Link>
        <Link to="/utility-calculations">
          <Button icon={<CalculatorOutlined />}>
            Calcule Utilități
          </Button>
        </Link>
        <Link to="/received-invoices">
          <Button icon={<FileSearchOutlined />}>
            Facturi Primite
          </Button>
        </Link>
      </div>
      </CollapsibleSection>
    </div>
  );
};

export default Dashboard;
