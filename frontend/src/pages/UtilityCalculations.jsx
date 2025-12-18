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
  Row,
  Col,
  Statistic,
  Typography,
  Spin,
  Empty,
  Steps,
  Tag,
  Collapse,
  Alert,
} from 'antd';
import {
  CalculatorOutlined,
  SaveOutlined,
  FileTextOutlined,
  ThunderboltOutlined,
  FileDoneOutlined,
  FileAddOutlined,
  CheckCircleOutlined,
  EuroOutlined,
  UserOutlined,
  QuestionCircleOutlined,
  InfoCircleOutlined,
} from '@ant-design/icons';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { utilityCalculationsService } from '../services/utilityCalculationsService';
import { receivedInvoicesService } from '../services/receivedInvoicesService';
import { meterReadingsService } from '../services/meterReadingsService';
import { tenantsService } from '../services/tenantsService';
import { invoicesService } from '../services/invoicesService';
import { formatCurrency, formatNumber, getMonthName } from '../utils/formatters';
import { UTILITY_TYPE_OPTIONS, getUtilityTypeLabel } from '../constants/utilityTypes';
import {
  ListSummaryCards,
  SummaryCard,
  ListPageHeader,
} from '../components/ui/ListSummaryCards';
import dayjs from 'dayjs';

const { Option } = Select;
const { Text } = Typography;

const UtilityCalculations = () => {
  const [form] = Form.useForm();
  const queryClient = useQueryClient();
  const [selectedYear, setSelectedYear] = useState(dayjs().year());
  const [selectedMonth, setSelectedMonth] = useState(dayjs().month() + 1);
  const [tenantPercentages, setTenantPercentages] = useState({});

  // Fetch received invoices for the selected period
  const { data: invoicesData, isLoading: invoicesLoading } = useQuery({
    queryKey: ['received-invoices-period', selectedYear, selectedMonth],
    queryFn: () => receivedInvoicesService.getByPeriod(selectedYear, selectedMonth),
    enabled: !!selectedYear && !!selectedMonth,
  });

  // Fetch meter readings for the selected period
  const { data: readingsData, isLoading: readingsLoading } = useQuery({
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
      const calcDetails = await utilityCalculationsService.getById(calculationId);
      const details = calcDetails?.data?.calculation?.details || [];
      const tenantIds = [...new Set(details.map(d => d.tenant_id))];

      if (tenantIds.length === 0) {
        message.warning('Nu există chiriași cu procente alocate pentru această perioadă. Configurați procentele în panoul din dreapta și salvați calculul din nou.');
        queryClient.invalidateQueries(['utility-calculations']);
        return;
      }

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
        queryClient.invalidateQueries(['utility-calculations']);
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
      overrides: tenantPercentages,
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

  // Check if calculation exists for current period
  const existingCalculation = useMemo(() => {
    return calculations.find(
      (calc) => calc.period_year === selectedYear && calc.period_month === selectedMonth
    );
  }, [calculations, selectedYear, selectedMonth]);

  const isPeriodFinalized = existingCalculation?.is_finalized;
  const hasExistingCalculation = !!existingCalculation;

  // Summary stats
  const stats = useMemo(() => {
    const totalInvoicesAmount = invoices.reduce((sum, inv) => sum + Number(inv.amount), 0);
    const totalTenantsAmount = Object.values(tenantCosts).reduce((sum, tc) => sum + tc.total, 0);
    const totalCompanyAmount = Object.values(companyPortions).reduce((sum, p) => sum + p.amount, 0);
    return {
      invoicesCount: invoices.length,
      totalInvoicesAmount,
      totalTenantsAmount,
      totalCompanyAmount,
      tenantsCount: activeTenants.length,
    };
  }, [invoices, tenantCosts, companyPortions, activeTenants]);

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
    const generalMeter = readings.find(
      (r) => r.is_general && r.meter_name && !r.meter_name.includes('Început')
    );

    const generalConsumption = generalMeter ? Number(generalMeter.consumption) || 0 : 0;

    const tenantConsumptionSum = readings
      .filter((r) => !r.is_general)
      .reduce((sum, r) => sum + (Number(r.consumption) || 0), 0);

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
      render: (isGeneral) => (
        <Tag color={isGeneral ? 'blue' : 'green'}>
          {isGeneral ? 'General' : 'Chiriaș'}
        </Tag>
      ),
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
        if (record.is_general) {
          return '-';
        }
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
      key: 'status',
      render: (_, record) => (
        <Space>
          <Tag color={record.is_finalized ? 'green' : 'blue'}>
            {record.is_finalized ? 'Finalizat' : 'Draft'}
          </Tag>
          {record.invoices_generated > 0 && (
            <Tag color="purple" icon={<FileDoneOutlined />}>
              {record.invoices_generated} facturi emise
            </Tag>
          )}
        </Space>
      ),
    },
    {
      title: 'Acțiuni',
      key: 'actions',
      render: (_, record) => {
        const hasInvoices = record.invoices_generated > 0;

        if (!record.is_finalized) {
          return (
            <Button
              type="primary"
              size="small"
              onClick={() => finalizeMutation.mutate(record.id)}
              loading={finalizeMutation.isPending}
            >
              Finalizează
            </Button>
          );
        }

        if (hasInvoices) {
          return (
            <Tag color="success" icon={<CheckCircleOutlined />}>
              Complet
            </Tag>
          );
        }

        return (
          <Button
            type="primary"
            size="small"
            icon={<FileDoneOutlined />}
            onClick={() => handleGenerateInvoices(record.id)}
            loading={generatingInvoices === record.id}
          >
            Emite Facturi
          </Button>
        );
      },
    },
  ];

  const isLoading = invoicesLoading || readingsLoading || tenantsLoading;

  // Determine current step based on data availability
  const getCurrentStep = () => {
    if (invoices.length === 0) return 0;
    if (readings.length === 0) return 1;
    if (activeTenants.length === 0) return 2;
    return 3;
  };

  const currentStep = getCurrentStep();

  return (
    <div>
      <ListPageHeader
        title="Calcule Utilități"
        subtitle={`Calculează și distribuie costurile utilităților pentru ${getMonthName(selectedMonth)} ${selectedYear}`}
        action={
          <Space>
            {isPeriodFinalized && (
              <Tag color="success" icon={<CheckCircleOutlined />}>
                Perioada finalizată
              </Tag>
            )}
            {hasExistingCalculation && !isPeriodFinalized && (
              <Tag color="processing">
                Calcul salvat (Draft)
              </Tag>
            )}
            <Button
              type="primary"
              icon={<SaveOutlined />}
              onClick={handleSaveCalculation}
              loading={createMutation.isPending}
              disabled={invoices.length === 0 || hasExistingCalculation}
            >
              Salvează Calcul
            </Button>
          </Space>
        }
      />

      <ListSummaryCards>
        <SummaryCard
          icon={<FileTextOutlined />}
          value={stats.invoicesCount}
          label="Facturi Primite"
          variant="default"
          subValue={stats.totalInvoicesAmount > 0 ? formatCurrency(stats.totalInvoicesAmount) : null}
        />
        <SummaryCard
          icon={<UserOutlined />}
          value={stats.tenantsCount}
          label="Chiriași Activi"
          variant="info"
          subValue={stats.totalTenantsAmount > 0 ? formatCurrency(stats.totalTenantsAmount) : null}
        />
        <SummaryCard
          icon={<EuroOutlined />}
          value={formatCurrency(stats.totalCompanyAmount)}
          label="Porțiune Firmă"
          variant="success"
        />
        <SummaryCard
          icon={<CalculatorOutlined />}
          value={calculations.length}
          label="Calcule Salvate"
          variant="warning"
        />
      </ListSummaryCards>

      {/* Workflow Steps */}
      <Card style={{ marginBottom: 24 }}>
        <Steps
          current={currentStep}
          items={[
            {
              title: 'Selectare Perioadă',
              description: 'Alegeți luna și anul',
              icon: <FileTextOutlined />,
            },
            {
              title: 'Adăugare Facturi',
              description: 'Introduceți facturile primite',
              icon: <FileAddOutlined />,
            },
            {
              title: 'Indexuri Contoare',
              description: 'Înregistrați citirile',
              icon: <ThunderboltOutlined />,
            },
            {
              title: 'Calcul și Generare',
              description: 'Generați facturi',
              icon: <CheckCircleOutlined />,
            },
          ]}
        />
      </Card>

      {/* Help Section */}
      <Collapse
        style={{ marginBottom: 24 }}
        items={[
          {
            key: 'help',
            label: (
              <Space>
                <QuestionCircleOutlined />
                <span>Cum funcționează calculul utilităților?</span>
              </Space>
            ),
            children: (
              <div className="pm-help-content">
                <Alert
                  type="info"
                  showIcon
                  icon={<InfoCircleOutlined />}
                  message="Procesul de calcul și facturare a utilităților"
                  description={
                    <div style={{ marginTop: 8 }}>
                      <p style={{ marginBottom: 12 }}>
                        Această pagină vă permite să calculați și să distribuiți costurile utilităților către chiriași,
                        pe baza procentelor alocate și a facturilor primite de la furnizori.
                      </p>

                      <Text strong>Pașii procesului:</Text>
                      <ol style={{ marginTop: 8, paddingLeft: 20 }}>
                        <li style={{ marginBottom: 8 }}>
                          <Text strong>Selectare Perioadă:</Text> Alegeți luna și anul pentru care doriți să faceți calculul.
                          Sistemul va încărca automat facturile primite și indexurile contoarelor pentru perioada selectată.
                        </li>
                        <li style={{ marginBottom: 8 }}>
                          <Text strong>Adăugare Facturi Primite:</Text> Asigurați-vă că ați introdus în secțiunea
                          "Facturi Primite" toate facturile de utilități pentru perioada selectată (electricitate, gaz, apă, internet, salubritate).
                        </li>
                        <li style={{ marginBottom: 8 }}>
                          <Text strong>Indexuri Contoare:</Text> Pentru electricitate, înregistrați citirile contoarelor
                          (atât cel general, cât și cele individuale ale chiriașilor) în secțiunea "Indexuri Contoare".
                        </li>
                        <li style={{ marginBottom: 8 }}>
                          <Text strong>Configurare Procente:</Text> În panoul din dreapta, configurați procentele de distribuție
                          pentru fiecare chiriaș și tip de utilitate. Procentele reprezintă cota parte din factură care va fi
                          facturată chiriașului. Diferența până la 100% rămâne în sarcina firmei.
                        </li>
                        <li style={{ marginBottom: 8 }}>
                          <Text strong>Salvare Calcul:</Text> După configurarea procentelor, apăsați "Salvează Calcul" pentru
                          a salva calculul curent. Calculul va apărea în tabelul "Calcule Anterioare" cu status "Draft".
                        </li>
                        <li style={{ marginBottom: 8 }}>
                          <Text strong>Finalizare:</Text> Apăsați "Finalizează" pentru a bloca calculul. După finalizare,
                          procentele nu mai pot fi modificate.
                        </li>
                        <li style={{ marginBottom: 8 }}>
                          <Text strong>Emitere Facturi:</Text> După finalizare, apăsați "Emite Facturi" pentru a genera
                          automat facturile de utilități pentru fiecare chiriaș. Facturile vor apărea în secțiunea "Facturi Emise".
                        </li>
                      </ol>

                      <Divider style={{ margin: '12px 0' }} />

                      <Text strong>Observații importante:</Text>
                      <ul style={{ marginTop: 8, paddingLeft: 20 }}>
                        <li>Procentele se salvează per chiriaș și se păstrează pentru lunile următoare</li>
                        <li>Diferența dintre consumul general și suma consumurilor individuale apare ca "Nealocat"</li>
                        <li>Porțiunea nealocată chiriașilor rămâne în sarcina firmei (afișată în verde)</li>
                        <li>Puteți modifica procentele oricând pentru calcule nefinalizate</li>
                      </ul>
                    </div>
                  }
                  style={{ marginBottom: 0 }}
                />
              </div>
            ),
          },
        ]}
      />

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
                        borderRadius: 'var(--pm-radius-lg)',
                        border: '1px solid var(--pm-color-warning)',
                        backgroundColor: 'var(--pm-color-warning-light)',
                      }}
                    >
                      <Row gutter={16} align="middle">
                        <Col flex="auto">
                          <Space direction="vertical" size={0}>
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
                                  color: meterStats.difference >= 0 ? 'var(--pm-color-warning)' : 'var(--pm-color-error)',
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
                                  color: 'var(--pm-color-warning)',
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
                                borderRadius: 'var(--pm-radius-md)',
                                border: '1px solid var(--pm-color-border-default)',
                                background: 'var(--pm-color-bg-tertiary)',
                              }}
                            >
                              <Text strong style={{ display: 'block', marginBottom: 4 }}>
                                {option.label}
                              </Text>
                              <Space direction="vertical" size={0} style={{ width: '100%' }}>
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
                                      color: 'var(--pm-color-primary)',
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
                <Card
                  size="small"
                  title="Porțiune Firmă"
                  style={{ background: 'var(--pm-color-success-light)' }}
                >
                  <Row gutter={[8, 8]}>
                    {UTILITY_TYPE_OPTIONS.map((option) => {
                      const portion = companyPortions[option.value];
                      if (!portion || portion.amount === 0) return null;
                      return (
                        <Col key={option.value} span={12}>
                          <div
                            style={{
                              padding: 8,
                              borderRadius: 'var(--pm-radius-md)',
                              border: '1px solid var(--pm-color-border-default)',
                              background: 'var(--pm-color-bg-secondary)',
                            }}
                          >
                            <Text strong>{option.label}</Text>
                            <div>
                              <Text type="secondary">{portion.percentage.toFixed(1)}%</Text>
                              {' = '}
                              <Text style={{ color: 'var(--pm-color-success)', fontWeight: 500 }}>
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
                    <Text strong style={{ fontSize: 16, color: 'var(--pm-color-success)' }}>
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
