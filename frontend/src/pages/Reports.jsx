import React, { useState, useRef } from 'react';
import {
  Card,
  Tabs,
  Table,
  Select,
  DatePicker,
  Button,
  Spin,
  Empty,
  Tag,
  Statistic,
  Row,
  Col,
  Typography,
  Progress,
  Calendar,
  Badge,
  message,
} from 'antd';
import {
  UserOutlined,
  CalendarOutlined,
  DownloadOutlined,
  PrinterOutlined,
  BarChartOutlined,
  CheckCircleOutlined,
  ClockCircleOutlined,
  FileTextOutlined,
  FilePdfOutlined,
} from '@ant-design/icons';
import { useQuery } from '@tanstack/react-query';
import { useSearchParams } from 'react-router-dom';
import dayjs from 'dayjs';
import { dashboardService } from '../services/dashboardService';
import { tenantsService } from '../services/tenantsService';
import { formatCurrency, formatDate } from '../utils/formatters';
import {
  exportCollectionReportPDF,
  exportTenantStatementPDF,
  exportCalendarPDF,
} from '../utils/pdfExport';
import '../styles/components/cards.css';

const { Title, Text } = Typography;
const { Option } = Select;

const Reports = () => {
  const [searchParams, setSearchParams] = useSearchParams();
  const initialTab = searchParams.get('tab') || 'collection';
  const [activeTab, setActiveTab] = useState(initialTab);

  // Collection Report state
  const [collectionYear, setCollectionYear] = useState(dayjs().year());
  const [collectionMonth, setCollectionMonth] = useState(null);

  // Tenant Statement state
  const [selectedTenantId, setSelectedTenantId] = useState(null);
  const [statementDateRange, setStatementDateRange] = useState([null, null]);

  // Calendar state
  const [calendarDate, setCalendarDate] = useState(dayjs());

  // Fetch tenants for dropdown
  const { data: tenantsData } = useQuery({
    queryKey: ['tenants-list'],
    queryFn: tenantsService.getAll,
  });

  // Fetch collection report
  const { data: collectionData, isLoading: collectionLoading } = useQuery({
    queryKey: ['collection-report', collectionYear, collectionMonth],
    queryFn: () => dashboardService.getCollectionReport(collectionYear, collectionMonth),
    enabled: activeTab === 'collection',
  });

  // Fetch tenant statement
  const { data: statementData, isLoading: statementLoading } = useQuery({
    queryKey: ['tenant-statement', selectedTenantId, statementDateRange],
    queryFn: () => dashboardService.getTenantStatement(
      selectedTenantId,
      statementDateRange[0]?.format('YYYY-MM-DD'),
      statementDateRange[1]?.format('YYYY-MM-DD')
    ),
    enabled: !!selectedTenantId && activeTab === 'statement',
  });

  // Fetch calendar events
  const { data: calendarData, isLoading: calendarLoading } = useQuery({
    queryKey: ['calendar-events', calendarDate.format('YYYY-MM')],
    queryFn: () => {
      const startDate = calendarDate.startOf('month').format('YYYY-MM-DD');
      const endDate = calendarDate.endOf('month').add(1, 'month').format('YYYY-MM-DD');
      return dashboardService.getCalendarEvents(startDate, endDate);
    },
    enabled: activeTab === 'calendar',
  });

  const tenantsRaw = tenantsData?.data?.tenants;
  const tenants = Array.isArray(tenantsRaw) ? tenantsRaw : [];
  const collectionReport = collectionData?.data || {};
  const collectionByType = Array.isArray(collectionReport.by_type) ? collectionReport.by_type : [];
  const collectionMonthly = Array.isArray(collectionReport.monthly) ? collectionReport.monthly : [];
  const statement = statementData?.data || {};
  const statementTransactions = Array.isArray(statement.transactions) ? statement.transactions : [];
  const calendarEventsRaw = calendarData?.data;
  const calendarEvents = Array.isArray(calendarEventsRaw) ? calendarEventsRaw : [];

  // Handle tab change
  const handleTabChange = (key) => {
    setActiveTab(key);
    setSearchParams({ tab: key });
  };

  // Collection report columns
  const typeBreakdownColumns = [
    {
      title: 'Tip Factură',
      dataIndex: 'type',
      key: 'type',
      render: (type) => {
        const labels = {
          rent: 'Chirie',
          utility: 'Utilități',
          utilities: 'Utilități',
          generic: 'Generic',
          other: 'Altele',
        };
        return labels[type] || type;
      },
    },
    {
      title: 'Emis',
      dataIndex: 'issued',
      key: 'issued',
      render: (val) => formatCurrency(parseFloat(val)),
      align: 'right',
    },
    {
      title: 'Încasat',
      dataIndex: 'collected',
      key: 'collected',
      render: (val) => formatCurrency(parseFloat(val)),
      align: 'right',
    },
    {
      title: 'Rată Încasare',
      dataIndex: 'collection_rate',
      key: 'collection_rate',
      render: (val) => (
        <Progress
          percent={parseFloat(val)}
          size="small"
          status={parseFloat(val) >= 80 ? 'success' : parseFloat(val) >= 50 ? 'normal' : 'exception'}
        />
      ),
      width: 150,
    },
  ];

  // Statement columns
  const statementColumns = [
    {
      title: 'Data',
      dataIndex: 'date',
      key: 'date',
      render: (date) => formatDate(date),
      width: 100,
    },
    {
      title: 'Descriere',
      dataIndex: 'description',
      key: 'description',
    },
    {
      title: 'Debit',
      dataIndex: 'debit',
      key: 'debit',
      render: (val) => val ? (
        <span style={{ color: 'var(--pm-color-error)' }}>
          {formatCurrency(parseFloat(val))}
        </span>
      ) : '-',
      align: 'right',
    },
    {
      title: 'Credit',
      dataIndex: 'credit',
      key: 'credit',
      render: (val) => val ? (
        <span style={{ color: 'var(--pm-color-success)' }}>
          {formatCurrency(parseFloat(val))}
        </span>
      ) : '-',
      align: 'right',
    },
    {
      title: 'Sold',
      dataIndex: 'balance',
      key: 'balance',
      render: (val) => {
        const value = parseFloat(val);
        return (
          <span style={{
            color: value > 0 ? 'var(--pm-color-error)' : 'var(--pm-color-success)',
            fontWeight: 600
          }}>
            {formatCurrency(value)}
          </span>
        );
      },
      align: 'right',
    },
  ];

  // Calendar cell renderer
  const dateCellRender = (value) => {
    const dateStr = value.format('YYYY-MM-DD');
    const dayEvents = calendarEvents.filter(e => e.date === dateStr);

    if (!dayEvents.length) return null;

    return (
      <ul style={{ listStyle: 'none', padding: 0, margin: 0 }}>
        {dayEvents.slice(0, 3).map((event) => (
          <li key={event.id} style={{ marginBottom: 2 }}>
            <Badge
              status={event.is_paid ? 'success' : event.type === 'expense' ? 'warning' : 'processing'}
              text={
                <span style={{ fontSize: 11, color: 'inherit' }}>
                  {formatCurrency(parseFloat(event.amount)).replace('RON', '')}
                </span>
              }
            />
          </li>
        ))}
        {dayEvents.length > 3 && (
          <li style={{ fontSize: 11, color: 'var(--pm-color-text-secondary)' }}>
            +{dayEvents.length - 3} mai multe
          </li>
        )}
      </ul>
    );
  };

  // Years for dropdown
  const years = [];
  const currentYear = dayjs().year();
  for (let y = currentYear; y >= currentYear - 5; y--) {
    years.push(y);
  }

  // Months for dropdown
  const months = [
    { value: 1, label: 'Ianuarie' },
    { value: 2, label: 'Februarie' },
    { value: 3, label: 'Martie' },
    { value: 4, label: 'Aprilie' },
    { value: 5, label: 'Mai' },
    { value: 6, label: 'Iunie' },
    { value: 7, label: 'Iulie' },
    { value: 8, label: 'August' },
    { value: 9, label: 'Septembrie' },
    { value: 10, label: 'Octombrie' },
    { value: 11, label: 'Noiembrie' },
    { value: 12, label: 'Decembrie' },
  ];

  const tabItems = [
    {
      key: 'collection',
      label: (
        <span>
          <BarChartOutlined />
          Situație Încasări
        </span>
      ),
      children: (
        <div>
          {/* Filters */}
          <div style={{ marginBottom: 24, display: 'flex', gap: 16, flexWrap: 'wrap', alignItems: 'center' }}>
            <div>
              <Text type="secondary" style={{ display: 'block', marginBottom: 4 }}>An</Text>
              <Select
                value={collectionYear}
                onChange={setCollectionYear}
                style={{ width: 120 }}
              >
                {years.map(y => (
                  <Option key={y} value={y}>{y}</Option>
                ))}
              </Select>
            </div>
            <div>
              <Text type="secondary" style={{ display: 'block', marginBottom: 4 }}>Lună (opțional)</Text>
              <Select
                value={collectionMonth}
                onChange={setCollectionMonth}
                style={{ width: 150 }}
                allowClear
                placeholder="Tot anul"
              >
                {months.map(m => (
                  <Option key={m.value} value={m.value}>{m.label}</Option>
                ))}
              </Select>
            </div>
            <div style={{ flex: 1 }} />
            <Button
              icon={<PrinterOutlined />}
              onClick={() => window.print()}
            >
              Printează
            </Button>
            <Button
              type="primary"
              icon={<FilePdfOutlined />}
              onClick={async () => {
                try {
                  await exportCollectionReportPDF(collectionReport, collectionYear, collectionMonth);
                  message.success('Raport exportat cu succes');
                } catch (err) {
                  console.error('PDF Export Error:', err);
                  message.error('Eroare la exportul raportului: ' + (err.message || 'Eroare necunoscută'));
                }
              }}
            >
              Export PDF
            </Button>
          </div>

          {collectionLoading ? (
            <div style={{ textAlign: 'center', padding: 60 }}>
              <Spin size="large" />
            </div>
          ) : (
            <>
              {/* Summary Cards */}
              <Row gutter={[24, 24]} style={{ marginBottom: 24 }}>
                <Col xs={24} sm={12} md={6}>
                  <Card className="pm-stat-card pm-stat-card--info" style={{ height: '100%' }}>
                    <Statistic
                      title="Total Emis"
                      value={parseFloat(collectionReport.summary?.issued_total || 0)}
                      formatter={(val) => formatCurrency(val)}
                      prefix={<FileTextOutlined />}
                    />
                    <div style={{ marginTop: 8, fontSize: 12, color: 'var(--pm-color-text-secondary)' }}>
                      {collectionReport.summary?.issued_count || 0} facturi
                    </div>
                  </Card>
                </Col>
                <Col xs={24} sm={12} md={6}>
                  <Card className="pm-stat-card pm-stat-card--success" style={{ height: '100%' }}>
                    <Statistic
                      title="Total Încasat"
                      value={parseFloat(collectionReport.summary?.collected_total || 0)}
                      formatter={(val) => formatCurrency(val)}
                      prefix={<CheckCircleOutlined />}
                      valueStyle={{ color: 'var(--pm-color-success)' }}
                    />
                    <div style={{ marginTop: 8, fontSize: 12, color: 'var(--pm-color-text-secondary)' }}>
                      {collectionReport.summary?.collected_count || 0} plăți
                    </div>
                  </Card>
                </Col>
                <Col xs={24} sm={12} md={6}>
                  <Card className="pm-stat-card pm-stat-card--warning" style={{ height: '100%' }}>
                    <Statistic
                      title="Rest de Încasat"
                      value={parseFloat(collectionReport.summary?.outstanding || 0)}
                      formatter={(val) => formatCurrency(val)}
                      prefix={<ClockCircleOutlined />}
                      valueStyle={{ color: 'var(--pm-color-warning)' }}
                    />
                    <div style={{ marginTop: 8, fontSize: 12, color: 'var(--pm-color-text-secondary)' }}>
                      {collectionReport.summary?.outstanding_count || 0} facturi restante
                    </div>
                  </Card>
                </Col>
                <Col xs={24} sm={12} md={6}>
                  <Card className="pm-stat-card" style={{ height: '100%' }}>
                    <Statistic
                      title="Rată Încasare"
                      value={parseFloat(collectionReport.summary?.collection_rate || 0)}
                      suffix="%"
                      prefix={<BarChartOutlined />}
                      valueStyle={{
                        color: parseFloat(collectionReport.summary?.collection_rate || 0) >= 80
                          ? 'var(--pm-color-success)'
                          : 'var(--pm-color-warning)'
                      }}
                    />
                    <Progress
                      percent={parseFloat(collectionReport.summary?.collection_rate || 0)}
                      showInfo={false}
                      status={parseFloat(collectionReport.summary?.collection_rate || 0) >= 80 ? 'success' : 'normal'}
                    />
                  </Card>
                </Col>
              </Row>

              {/* Breakdown by Type */}
              <Card title="Detaliere pe Tip Factură" style={{ marginBottom: 24 }}>
                <Table
                  columns={typeBreakdownColumns}
                  dataSource={collectionByType}
                  rowKey="type"
                  pagination={false}
                  size="small"
                />
              </Card>

              {/* Monthly Breakdown (if showing full year) */}
              {!collectionMonth && collectionMonthly.length > 0 && (
                <Card title="Evoluție Lunară">
                  <Table
                    columns={[
                      {
                        title: 'Lună',
                        dataIndex: 'month',
                        key: 'month',
                        render: (m) => months.find(mo => mo.value === m)?.label || m,
                      },
                      {
                        title: 'Emis',
                        dataIndex: 'issued',
                        key: 'issued',
                        render: (val) => formatCurrency(parseFloat(val)),
                        align: 'right',
                      },
                      {
                        title: 'Încasat',
                        dataIndex: 'collected',
                        key: 'collected',
                        render: (val) => formatCurrency(parseFloat(val)),
                        align: 'right',
                      },
                      {
                        title: 'Diferență',
                        key: 'diff',
                        render: (_, record) => {
                          const diff = parseFloat(record.issued) - parseFloat(record.collected);
                          return (
                            <span style={{ color: diff > 0 ? 'var(--pm-color-error)' : 'var(--pm-color-success)' }}>
                              {formatCurrency(diff)}
                            </span>
                          );
                        },
                        align: 'right',
                      },
                    ]}
                    dataSource={collectionMonthly}
                    rowKey="month"
                    pagination={false}
                    size="small"
                  />
                </Card>
              )}
            </>
          )}
        </div>
      ),
    },
    {
      key: 'statement',
      label: (
        <span>
          <UserOutlined />
          Extras de Cont
        </span>
      ),
      children: (
        <div>
          {/* Filters */}
          <div style={{ marginBottom: 24, display: 'flex', gap: 16, flexWrap: 'wrap', alignItems: 'flex-end' }}>
            <div>
              <Text type="secondary" style={{ display: 'block', marginBottom: 4 }}>Chiriaș *</Text>
              <Select
                value={selectedTenantId}
                onChange={setSelectedTenantId}
                style={{ width: 250 }}
                placeholder="Selectează chiriaș"
                showSearch
                optionFilterProp="children"
              >
                {tenants.map(t => (
                  <Option key={t.id} value={t.id}>{t.name}</Option>
                ))}
              </Select>
            </div>
            <div>
              <Text type="secondary" style={{ display: 'block', marginBottom: 4 }}>Perioadă (opțional)</Text>
              <DatePicker.RangePicker
                value={statementDateRange}
                onChange={setStatementDateRange}
                format="DD.MM.YYYY"
                placeholder={['De la', 'Până la']}
              />
            </div>
            <div style={{ flex: 1 }} />
            <Button
              icon={<PrinterOutlined />}
              disabled={!selectedTenantId}
              onClick={() => window.print()}
            >
              Printează
            </Button>
            <Button
              type="primary"
              icon={<FilePdfOutlined />}
              disabled={!selectedTenantId}
              onClick={async () => {
                try {
                  await exportTenantStatementPDF(statement);
                  message.success('Extras de cont exportat cu succes');
                } catch (err) {
                  console.error('PDF Export Error:', err);
                  message.error('Eroare la exportul extrasului: ' + (err.message || 'Eroare necunoscută'));
                }
              }}
            >
              Export PDF
            </Button>
          </div>

          {!selectedTenantId ? (
            <Empty
              description="Selectează un chiriaș pentru a vedea extrasul de cont"
              image={Empty.PRESENTED_IMAGE_SIMPLE}
            />
          ) : statementLoading ? (
            <div style={{ textAlign: 'center', padding: 60 }}>
              <Spin size="large" />
            </div>
          ) : (
            <>
              {/* Tenant Info */}
              <Card style={{ marginBottom: 24 }}>
                <Row gutter={24}>
                  <Col span={8}>
                    <Text type="secondary">Chiriaș</Text>
                    <Title level={4} style={{ margin: '4px 0' }}>{statement.tenant?.name}</Title>
                    <Text type="secondary">{statement.tenant?.email}</Text>
                  </Col>
                  <Col span={8}>
                    <Text type="secondary">Total Facturat</Text>
                    <Title level={4} style={{ margin: '4px 0' }}>
                      {formatCurrency(parseFloat(statement.summary?.total_invoiced || 0))}
                    </Title>
                  </Col>
                  <Col span={8}>
                    <Text type="secondary">Sold Curent</Text>
                    <Title
                      level={4}
                      style={{
                        margin: '4px 0',
                        color: parseFloat(statement.summary?.current_balance || 0) > 0
                          ? 'var(--pm-color-error)'
                          : 'var(--pm-color-success)'
                      }}
                    >
                      {formatCurrency(parseFloat(statement.summary?.current_balance || 0))}
                    </Title>
                  </Col>
                </Row>
              </Card>

              {/* Transactions Table */}
              <Card title="Tranzacții">
                <Table
                  columns={statementColumns}
                  dataSource={statementTransactions}
                  rowKey={(record, index) => `${record.date}-${record.type}-${index}`}
                  pagination={{ pageSize: 20 }}
                  size="small"
                  summary={() => {
                    const lastTransaction = statementTransactions.length > 0 ? statementTransactions[statementTransactions.length - 1] : null;
                    return (
                      <Table.Summary.Row>
                        <Table.Summary.Cell index={0} colSpan={4}>
                          <strong>Sold Final</strong>
                        </Table.Summary.Cell>
                        <Table.Summary.Cell index={4} align="right">
                          <strong style={{
                            color: parseFloat(lastTransaction?.balance || 0) > 0
                              ? 'var(--pm-color-error)'
                              : 'var(--pm-color-success)'
                          }}>
                            {formatCurrency(parseFloat(lastTransaction?.balance || 0))}
                          </strong>
                        </Table.Summary.Cell>
                      </Table.Summary.Row>
                    );
                  }}
                />
              </Card>
            </>
          )}
        </div>
      ),
    },
    {
      key: 'calendar',
      label: (
        <span>
          <CalendarOutlined />
          Calendar Scadențe
        </span>
      ),
      children: (
        <div>
          {calendarLoading ? (
            <div style={{ textAlign: 'center', padding: 60 }}>
              <Spin size="large" />
            </div>
          ) : (
            <>
              {/* Legend and Export */}
              <div style={{ marginBottom: 16, display: 'flex', gap: 24, alignItems: 'center', flexWrap: 'wrap' }}>
                <span><Badge status="processing" /> De încasat (facturi emise)</span>
                <span><Badge status="warning" /> De plătit (facturi utilități)</span>
                <span><Badge status="success" /> Plătit</span>
                <div style={{ flex: 1 }} />
                <Button
                  icon={<PrinterOutlined />}
                  onClick={() => window.print()}
                >
                  Printează
                </Button>
                <Button
                  type="primary"
                  icon={<FilePdfOutlined />}
                  onClick={async () => {
                    try {
                      const monthEvents = calendarEvents.filter(e => {
                        const eventMonth = dayjs(e.date).format('YYYY-MM');
                        const selectedMonth = calendarDate.format('YYYY-MM');
                        return eventMonth === selectedMonth;
                      });
                      await exportCalendarPDF(monthEvents, calendarDate);
                      message.success('Calendar exportat cu succes');
                    } catch (err) {
                      console.error('PDF Export Error:', err);
                      message.error('Eroare la exportul calendarului: ' + (err.message || 'Eroare necunoscută'));
                    }
                  }}
                >
                  Export PDF
                </Button>
              </div>

              <Card>
                <Calendar
                  cellRender={(current, info) => {
                    if (info.type === 'date') {
                      return dateCellRender(current);
                    }
                    return info.originNode;
                  }}
                  value={calendarDate}
                  onChange={setCalendarDate}
                />
              </Card>

              {/* Events List for Selected Month */}
              <Card title="Scadențe Luna Curentă" style={{ marginTop: 24 }}>
                <Table
                  columns={[
                    {
                      title: 'Data',
                      dataIndex: 'date',
                      key: 'date',
                      render: (date) => formatDate(date),
                      width: 100,
                    },
                    {
                      title: 'Tip',
                      dataIndex: 'type',
                      key: 'type',
                      render: (type) => (
                        <Tag color={type === 'income' ? 'blue' : 'orange'}>
                          {type === 'income' ? 'Încasare' : 'Plată'}
                        </Tag>
                      ),
                      width: 100,
                    },
                    {
                      title: 'Descriere',
                      dataIndex: 'title',
                      key: 'title',
                    },
                    {
                      title: 'Sumă',
                      dataIndex: 'amount',
                      key: 'amount',
                      render: (val) => formatCurrency(parseFloat(val)),
                      align: 'right',
                    },
                    {
                      title: 'Status',
                      dataIndex: 'is_paid',
                      key: 'is_paid',
                      render: (isPaid) => (
                        <Tag color={isPaid ? 'success' : 'warning'}>
                          {isPaid ? 'Plătit' : 'În așteptare'}
                        </Tag>
                      ),
                    },
                  ]}
                  dataSource={calendarEvents.filter(e => {
                    const eventMonth = dayjs(e.date).format('YYYY-MM');
                    const selectedMonth = calendarDate.format('YYYY-MM');
                    return eventMonth === selectedMonth;
                  })}
                  rowKey="id"
                  pagination={false}
                  size="small"
                />
              </Card>
            </>
          )}
        </div>
      ),
    },
  ];

  return (
    <div className="pm-page">
      <div className="pm-page__header">
        <Title level={2}>Rapoarte</Title>
        <Text type="secondary">Vizualizare situație încasări, extrase de cont și calendar scadențe</Text>
      </div>

      <Tabs
        activeKey={activeTab}
        onChange={handleTabChange}
        items={tabItems}
        size="large"
      />
    </div>
  );
};

export default Reports;
