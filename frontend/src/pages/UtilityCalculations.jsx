import React, { useState, useEffect, useMemo } from 'react';
import {
  Card,
  Button,
  Form,
  Select,
  InputNumber,
  Table,
  message,
  Space,
  Divider,
  Alert,
  Row,
  Col,
  Statistic,
  Typography,
  Spin,
  Empty,
  Steps,
} from 'antd';
import {
  CalculatorOutlined,
  SaveOutlined,
  FileTextOutlined,
  ThunderboltOutlined,
  FileDoneOutlined,
  FileAddOutlined,
  CheckCircleOutlined,
} from '@ant-design/icons';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { utilityCalculationsService } from '../services/utilityCalculationsService';
import { receivedInvoicesService } from '../services/receivedInvoicesService';
import { meterReadingsService } from '../services/meterReadingsService';
import { tenantsService } from '../services/tenantsService';
import { invoicesService } from '../services/invoicesService';
import { formatCurrency, formatNumber, getMonthName } from '../utils/formatters';
import { UTILITY_TYPE_OPTIONS, getUtilityTypeLabel } from '../constants/utilityTypes';
import dayjs from 'dayjs';

const { Option } = Select;
const { Title, Text } = Typography;

const UtilityCalculations = () => {
  const [form] = Form.useForm();
  const queryClient = useQueryClient();
  const [selectedYear, setSelectedYear] = useState(dayjs().year());
  const [selectedMonth, setSelectedMonth] = useState(dayjs().month() + 1);
  const [tenantPercentages, setTenantPercentages] = useState({});
  const [isCalculating, setIsCalculating] = useState(false);

  // Fetch received invoices for the selected period
  const { data: invoicesData, isLoading: invoicesLoading, refetch: refetchInvoices } = useQuery({
    queryKey: ['received-invoices-period', selectedYear, selectedMonth],
    queryFn: () => receivedInvoicesService.getByPeriod(selectedYear, selectedMonth),
    enabled: !!selectedYear && !!selectedMonth,
  });

  // Fetch meter readings for the selected period
  const { data: readingsData, isLoading: readingsLoading, refetch: refetchReadings } = useQuery({
    queryKey: ['meter-readings-period', selectedYear, selectedMonth],
    queryFn: () => meterReadingsService.getByPeriod(selectedYear, selectedMonth),
    enabled: !!selectedYear && !!selectedMonth,
  });

  // Fetch tenants with their percentages
  const { data: tenantsData, isLoading: tenantsLoading } = useQuery({
    queryKey: ['tenants'],
    queryFn: () => tenantsService.getAll(),
  });

  // Fetch previous calculations
  const { data: calculationsData, isLoading: calculationsLoading } = useQuery({
    queryKey: ['utility-calculations'],
    queryFn: () => utilityCalculationsService.getAll(),
  });

  // Initialize tenant percentages from fetched data
  useEffect(() => {
    if (tenantsData?.data?.tenants) {
      const percentages = {};
      tenantsData.data.tenants.forEach((tenant) => {
        if (tenant.is_active) {
          percentages[tenant.id] = {};
          UTILITY_TYPE_OPTIONS.forEach((option) => {
            const existing = tenant.utility_percentages?.find(
              (up) => up.utility_type === option.value
            );
            percentages[tenant.id][option.value] = existing?.percentage || 0;
          });
        }
      });
      setTenantPercentages(percentages);
    }
  }, [tenantsData]);

  // Update percentage mutation
  const updatePercentagesMutation = useMutation({
    mutationFn: ({ tenantId, percentages }) =>
      tenantsService.updatePercentages(tenantId, percentages),
    onSuccess: () => {
      message.success('Procente actualizate!');
      queryClient.invalidateQueries(['tenants']);
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la actualizare');
    },
  });

  // Save calculation mutation
  const createMutation = useMutation({
    mutationFn: (data) => utilityCalculationsService.create(data),
    onSuccess: () => {
      message.success('Calcul salvat cu succes!');
      queryClient.invalidateQueries(['utility-calculations']);
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la salvare');
    },
  });

  const finalizeMutation = useMutation({
    mutationFn: (id) => utilityCalculationsService.finalize(id),
    onSuccess: () => {
      message.success('Calcul finalizat cu succes!');
      queryClient.invalidateQueries(['utility-calculations']);
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la finalizare');
    },
  });

  const [generatingInvoices, setGeneratingInvoices] = useState(null);

  const handleGenerateInvoices = async (calculationId) => {
    setGeneratingInvoices(calculationId);
    try {
      // Get calculation details to find tenants
      const calcDetails = await utilityCalculationsService.getById(calculationId);
      const details = calcDetails?.data?.calculation?.details || [];

      // Group by tenant to avoid duplicate invoices
      const tenantIds = [...new Set(details.map(d => d.tenant_id))];

      let successCount = 0;
      let errorCount = 0;

      for (const tenantId of tenantIds) {
        try {
          await invoicesService.createUtility({
            tenant_id: tenantId,
            calculation_id: calculationId,
          });
          successCount++;
        } catch (err) {
          console.error(`Failed to create invoice for tenant ${tenantId}:`, err);
          errorCount++;
        }
      }

      if (successCount > 0) {
        message.success(`${successCount} facturi create cu succes!`);
        queryClient.invalidateQueries(['invoices']);
      }
      if (errorCount > 0) {
        message.warning(`${errorCount} facturi nu au putut fi create.`);
      }
    } catch (error) {
      message.error(error.response?.data?.error || 'Eroare la generare facturi');
    } finally {
      setGeneratingInvoices(null);
    }
  };

  const handlePeriodChange = () => {
    const values = form.getFieldsValue();
    setSelectedYear(values.year);
    setSelectedMonth(values.month);
  };

  const handlePercentageChange = (tenantId, utilityType, value) => {
    setTenantPercentages((prev) => ({
      ...prev,
      [tenantId]: {
        ...prev[tenantId],
        [utilityType]: value || 0,
      },
    }));
  };

  const handleSavePercentages = (tenantId) => {
    updatePercentagesMutation.mutate({
      tenantId,
      percentages: tenantPercentages[tenantId],
    });
  };

  const handleSaveCalculation = () => {
    createMutation.mutate({
      period_year: selectedYear,
      period_month: selectedMonth,
    });
  };

  // Get invoices grouped by utility type
  const invoices = invoicesData?.data || [];
  const invoicesByType = useMemo(() => {
    const grouped = {};
    invoices.forEach((inv) => {
      if (!grouped[inv.utility_type]) {
        grouped[inv.utility_type] = [];
      }
      grouped[inv.utility_type].push(inv);
    });
    return grouped;
  }, [invoices]);

  // Get total amount per utility type
  const totalsByType = useMemo(() => {
    const totals = {};
    invoices.forEach((inv) => {
      totals[inv.utility_type] = (totals[inv.utility_type] || 0) + Number(inv.amount);
    });
    return totals;
  }, [invoices]);

  // Get meter readings
  const readings = readingsData?.data || [];

  // Get active tenants
  const activeTenants = useMemo(() => {
    return (tenantsData?.data?.tenants || []).filter((t) => t.is_active);
  }, [tenantsData]);

  // Calculate costs per tenant
  const tenantCosts = useMemo(() => {
    const costs = {};
    activeTenants.forEach((tenant) => {
      costs[tenant.id] = {
        tenant_name: tenant.name,
        utilities: {},
        total: 0,
      };

      UTILITY_TYPE_OPTIONS.forEach((option) => {
        const utilityType = option.value;
        const invoiceTotal = totalsByType[utilityType] || 0;
        const percentage = tenantPercentages[tenant.id]?.[utilityType] || 0;
        const amount = (invoiceTotal * percentage) / 100;

        costs[tenant.id].utilities[utilityType] = {
          invoice_total: invoiceTotal,
          percentage: percentage,
          amount: amount,
        };
        costs[tenant.id].total += amount;
      });
    });
    return costs;
  }, [activeTenants, totalsByType, tenantPercentages]);

  // Calculate company portions (100% - sum of tenant percentages)
  const companyPortions = useMemo(() => {
    const portions = {};
    UTILITY_TYPE_OPTIONS.forEach((option) => {
      const utilityType = option.value;
      const invoiceTotal = totalsByType[utilityType] || 0;
      let tenantPctSum = 0;
      activeTenants.forEach((tenant) => {
        tenantPctSum += tenantPercentages[tenant.id]?.[utilityType] || 0;
      });
      const companyPct = Math.max(0, 100 - tenantPctSum);
      portions[utilityType] = {
        percentage: companyPct,
        amount: (invoiceTotal * companyPct) / 100,
      };
    });
    return portions;
  }, [totalsByType, activeTenants, tenantPercentages]);

  const calculations = calculationsData?.data || [];

  const invoicesColumns = [
    {
      title: 'Nr. Factură',
      dataIndex: 'invoice_number',
      key: 'invoice_number',
    },
    {
      title: 'Furnizor',
      dataIndex: 'provider_name',
      key: 'provider_name',
    },
    {
      title: 'Tip',
      dataIndex: 'utility_type',
      key: 'utility_type',
      render: (type) => getUtilityTypeLabel(type),
    },
    {
      title: 'Sumă',
      dataIndex: 'amount',
      key: 'amount',
      render: (val) => formatCurrency(val),
      align: 'right',
    },
  ];

  // Calculate meter statistics
  const meterStats = useMemo(() => {
    // Find GM-001 (General meter - the main reference meter)
    // This is the general meter that has a reading date (not "Început Lună")
    const generalMeter = readings.find(
      (r) => r.is_general && r.meter_name && !r.meter_name.includes('Început')
    );

    const generalConsumption = generalMeter ? Number(generalMeter.consumption) || 0 : 0;

    // Calculate sum of all non-general meter consumptions (excluding GM-002)
    const tenantConsumptionSum = readings
      .filter((r) => !r.is_general)
      .reduce((sum, r) => sum + (Number(r.consumption) || 0), 0);

    // Calculate difference (unallocated consumption)
    const difference = generalConsumption - tenantConsumptionSum;

    return {
      generalMeter,
      generalConsumption,
      tenantConsumptionSum,
      difference,
    };
  }, [readings]);

  const readingsColumns = [
    {
      title: 'Contor',
      dataIndex: 'meter_name',
      key: 'meter_name',
    },
    {
      title: 'Tip',
      dataIndex: 'is_general',
      key: 'is_general',
      render: (isGeneral) => (isGeneral ? 'General' : 'Chiriaș'),
    },
    {
      title: 'Index Anterior',
      dataIndex: 'previous_reading_value',
      key: 'previous_reading_value',
      render: (val) => (val != null ? formatNumber(val) : '-'),
      align: 'right',
    },
    {
      title: 'Index Curent',
      dataIndex: 'reading_value',
      key: 'reading_value',
      render: (val) => formatNumber(val),
      align: 'right',
    },
    {
      title: 'Consum',
      dataIndex: 'consumption',
      key: 'consumption',
      render: (val) => {
        const num = Number(val) || 0;
        return <strong>{formatNumber(num)}</strong>;
      },
      align: 'right',
    },
    {
      title: '% din General',
      dataIndex: 'consumption',
      key: 'percentage',
      render: (consumption, record) => {
        // Don't show percentage for general meters
        if (record.is_general) {
          return '-';
        }

        // Calculate percentage if we have a general meter consumption
        if (meterStats.generalConsumption > 0) {
          const percentage = (Number(consumption) || 0) / meterStats.generalConsumption * 100;
          return <Text>{percentage.toFixed(2)}%</Text>;
        }

        return '-';
      },
      align: 'right',
    },
  ];

  const calculationsColumns = [
    {
      title: 'Perioadă',
      key: 'period',
      render: (_, record) =>
        `${getMonthName(record.period_month)} ${record.period_year}`,
      sorter: (a, b) =>
        a.period_year * 12 + a.period_month - (b.period_year * 12 + b.period_month),
      defaultSortOrder: 'descend',
    },
    {
      title: 'Status',
      dataIndex: 'is_finalized',
      key: 'is_finalized',
      render: (isFinalized) => (
        <span
          style={{
            color: isFinalized ? '#52c41a' : '#1890ff',
            fontWeight: 500,
          }}
        >
          {isFinalized ? 'Finalizat' : 'Draft'}
        </span>
      ),
    },
    {
      title: 'Acțiuni',
      key: 'actions',
      render: (_, record) => (
        <Space>
          {!record.is_finalized && (
            <Button
              type="primary"
              size="small"
              onClick={() => finalizeMutation.mutate(record.id)}
              loading={finalizeMutation.isPending}
            >
              Finalizează
            </Button>
          )}
          {record.is_finalized && (
            <Button
              type="primary"
              size="small"
              icon={<FileDoneOutlined />}
              onClick={() => handleGenerateInvoices(record.id)}
              loading={generatingInvoices === record.id}
            >
              Emite Facturi
            </Button>
          )}
        </Space>
      ),
    },
  ];

  const isLoading = invoicesLoading || readingsLoading || tenantsLoading;

  // Determine current step based on data availability
  const getCurrentStep = () => {
    if (invoices.length === 0) return 0; // Select Period
    if (readings.length === 0) return 1; // Add Invoices
    if (activeTenants.length === 0) return 2; // Add meter readings
    return 3; // Calculate and Generate
  };

  const currentStep = getCurrentStep();

  return (
    <div>
      <Title level={2} style={{ marginBottom: 24 }}>Calcule Utilități</Title>

      {/* Workflow Steps */}
      <Card style={{ marginBottom: 24 }}>
        <Steps
          current={currentStep}
          items={[
            {
              title: 'Selectare Perioadă',
              content: 'Alegeți luna și anul',
              icon: <FileTextOutlined />,
            },
            {
              title: 'Adăugare Facturi',
              content: 'Introduceți facturile primite',
              icon: <FileAddOutlined />,
            },
            {
              title: 'Indexuri Contoare',
              content: 'Înregistrați citirile contoarelor',
              icon: <ThunderboltOutlined />,
            },
            {
              title: 'Calcul și Generare',
              content: 'Calculați și generați facturi',
              icon: <CheckCircleOutlined />,
            },
          ]}
        />
      </Card>

      {/* Period Selection */}
      <Card style={{ marginBottom: 24 }}>
        <Form
          form={form}
          layout="inline"
          initialValues={{ month: selectedMonth, year: selectedYear }}
        >
          <Form.Item label="Lună" name="month" rules={[{ required: true }]}>
            <Select style={{ width: 160 }} onChange={handlePeriodChange}>
              {Array.from({ length: 12 }, (_, i) => i + 1).map((month) => (
                <Option key={month} value={month}>
                  {getMonthName(month)}
                </Option>
              ))}
            </Select>
          </Form.Item>

          <Form.Item label="An" name="year" rules={[{ required: true }]}>
            <InputNumber
              min={2020}
              max={2100}
              style={{ width: 120 }}
              onChange={handlePeriodChange}
            />
          </Form.Item>

          <Form.Item>
            <Button
              type="primary"
              icon={<SaveOutlined />}
              onClick={handleSaveCalculation}
              loading={createMutation.isPending}
              disabled={invoices.length === 0}
            >
              Salvează Calcul
            </Button>
          </Form.Item>
        </Form>
      </Card>

      {isLoading ? (
        <div style={{ textAlign: 'center', padding: 48 }}>
          <Spin size="large" />
        </div>
      ) : (
        <Row gutter={24}>
          {/* Left Column - Invoices and Readings */}
          <Col xs={24} lg={12}>
            {/* Received Invoices */}
            <Card
              title={
                <Space>
                  <FileTextOutlined />
                  <span>
                    Facturi Primite - {getMonthName(selectedMonth)} {selectedYear}
                  </span>
                </Space>
              }
              style={{ marginBottom: 24 }}
            >
              {invoices.length === 0 ? (
                <Empty description="Nu există facturi pentru această perioadă" />
              ) : (
                <>
                  <Table
                    columns={invoicesColumns}
                    dataSource={invoices}
                    rowKey="id"
                    pagination={false}
                    size="small"
                  />
                  <Divider />
                  <Row gutter={16}>
                    {UTILITY_TYPE_OPTIONS.map((option) => {
                      const total = totalsByType[option.value] || 0;
                      if (total === 0) return null;
                      return (
                        <Col key={option.value} span={8}>
                          <Statistic
                            title={option.label}
                            value={total}
                            precision={2}
                            suffix="RON"
                          />
                        </Col>
                      );
                    })}
                  </Row>
                </>
              )}
            </Card>

            {/* Meter Readings */}
            <Card
              title={
                <Space>
                  <ThunderboltOutlined />
                  <span>
                    Indexuri Contoare - {getMonthName(selectedMonth)} {selectedYear}
                  </span>
                </Space>
              }
              style={{ marginBottom: 24 }}
            >
              {readings.length === 0 ? (
                <Empty description="Nu există indexuri pentru această perioadă" />
              ) : (
                <>
                  <Table
                    columns={readingsColumns}
                    dataSource={readings}
                    rowKey="id"
                    pagination={false}
                    size="small"
                  />
                  {/* Summary Row - Difference (Unallocated Consumption) */}
                  {meterStats.generalMeter && (
                    <div
                      style={{
                        marginTop: 16,
                        padding: 12,
                        borderRadius: 4,
                        border: '1px solid #ffd591',
                        backgroundColor: 'var(--ant-color-warning-bg)',
                      }}
                    >
                      <Row gutter={16} align="middle">
                        <Col flex="auto">
                          <Space orientation="vertical" size={0}>
                            <Text strong style={{ fontSize: 14 }}>
                              Diferență (Nealocat)
                            </Text>
                            <Text type="secondary" style={{ fontSize: 12 }}>
                              Consum General - Suma Chiriași
                            </Text>
                          </Space>
                        </Col>
                        <Col>
                          <Space size={24}>
                            <Statistic
                              title="Consum General"
                              value={meterStats.generalConsumption}
                              precision={2}
                              styles={{ value: { fontSize: 16 } }}
                            />
                            <Statistic
                              title="Total Chiriași"
                              value={meterStats.tenantConsumptionSum}
                              precision={2}
                              styles={{ value: { fontSize: 16 } }}
                            />
                            <Statistic
                              title="Diferență"
                              value={meterStats.difference}
                              precision={2}
                              styles={{
                                value: {
                                  fontSize: 18,
                                  color: meterStats.difference >= 0 ? '#faad14' : '#cf1322',
                                  fontWeight: 'bold',
                                }
                              }}
                            />
                            <Statistic
                              title="% Nealocat"
                              value={
                                meterStats.generalConsumption > 0
                                  ? (meterStats.difference / meterStats.generalConsumption) * 100
                                  : 0
                              }
                              precision={2}
                              suffix="%"
                              styles={{
                                value: {
                                  fontSize: 16,
                                  color: '#faad14',
                                }
                              }}
                            />
                          </Space>
                        </Col>
                      </Row>
                    </div>
                  )}
                </>
              )}
            </Card>
          </Col>

          {/* Right Column - Tenant Percentages and Costs */}
          <Col xs={24} lg={12}>
            {/* Tenant Percentages */}
            <Card
              title={
                <Space>
                  <CalculatorOutlined />
                  <span>Procente și Costuri Chiriași</span>
                </Space>
              }
              style={{ marginBottom: 24 }}
            >
              {activeTenants.length === 0 ? (
                <Empty description="Nu există chiriași activi" />
              ) : (
                activeTenants.map((tenant) => (
                  <Card
                    key={tenant.id}
                    size="small"
                    title={tenant.name}
                    style={{ marginBottom: 16 }}
                    extra={
                      <Button
                        size="small"
                        onClick={() => handleSavePercentages(tenant.id)}
                        loading={updatePercentagesMutation.isPending}
                      >
                        Salvează %
                      </Button>
                    }
                  >
                    <Row gutter={[8, 8]}>
                      {UTILITY_TYPE_OPTIONS.map((option) => {
                        const cost =
                          tenantCosts[tenant.id]?.utilities[option.value];
                        const invoiceTotal = totalsByType[option.value] || 0;

                        return (
                          <Col key={option.value} span={12}>
                            <div
                              style={{
                                padding: 8,
                                borderRadius: 4,
                                border: '1px solid',
                                borderColor: 'var(--ant-color-border)',
                              }}
                            >
                              <Text strong style={{ display: 'block', marginBottom: 4 }}>
                                {option.label}
                              </Text>
                              <Space orientation="vertical" size={0} style={{ width: '100%' }}>
                                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                                  <InputNumber
                                    min={0}
                                    max={100}
                                    value={
                                      tenantPercentages[tenant.id]?.[option.value] || 0
                                    }
                                    onChange={(val) =>
                                      handlePercentageChange(tenant.id, option.value, val)
                                    }
                                    style={{ width: 70 }}
                                    size="small"
                                  />
                                  <Text type="secondary">%</Text>
                                </div>
                                {invoiceTotal > 0 ? (
                                  <Text
                                    style={{
                                      color: '#1890ff',
                                      fontWeight: 500,
                                    }}
                                  >
                                    = {formatCurrency(cost?.amount || 0)}
                                  </Text>
                                ) : (
                                  <Text type="secondary" style={{ fontSize: 12 }}>
                                    Fără factură
                                  </Text>
                                )}
                              </Space>
                            </div>
                          </Col>
                        );
                      })}
                    </Row>
                    <Divider style={{ margin: '12px 0' }} />
                    <div style={{ textAlign: 'right' }}>
                      <Text strong style={{ fontSize: 16 }}>
                        Total: {formatCurrency(tenantCosts[tenant.id]?.total || 0)}
                      </Text>
                    </div>
                  </Card>
                ))
              )}

              {/* Company Portion */}
              {Object.values(companyPortions).some((p) => p.amount > 0) && (
                <Card size="small" title="Porțiune Firmă" style={{ backgroundColor: '#f6ffed' }}>
                  <Row gutter={[8, 8]}>
                    {UTILITY_TYPE_OPTIONS.map((option) => {
                      const portion = companyPortions[option.value];
                      if (!portion || portion.amount === 0) return null;
                      return (
                        <Col key={option.value} span={12}>
                          <div
                            style={{
                              padding: 8,
                              borderRadius: 4,
                              border: '1px solid',
                              borderColor: 'var(--ant-color-border)',
                            }}
                          >
                            <Text strong>{option.label}</Text>
                            <div>
                              <Text type="secondary">{portion.percentage.toFixed(1)}%</Text>
                              {' = '}
                              <Text style={{ color: '#52c41a', fontWeight: 500 }}>
                                {formatCurrency(portion.amount)}
                              </Text>
                            </div>
                          </div>
                        </Col>
                      );
                    })}
                  </Row>
                  <Divider style={{ margin: '12px 0' }} />
                  <div style={{ textAlign: 'right' }}>
                    <Text strong style={{ fontSize: 16, color: '#52c41a' }}>
                      Total:{' '}
                      {formatCurrency(
                        Object.values(companyPortions).reduce(
                          (sum, p) => sum + p.amount,
                          0
                        )
                      )}
                    </Text>
                  </div>
                </Card>
              )}
            </Card>
          </Col>
        </Row>
      )}

      {/* Previous Calculations */}
      <Card title="Calcule Anterioare" style={{ marginTop: 24 }}>
        <Table
          columns={calculationsColumns}
          dataSource={calculations}
          rowKey="id"
          loading={calculationsLoading}
          pagination={{ pageSize: 10 }}
        />
      </Card>
    </div>
  );
};

export default UtilityCalculations;
