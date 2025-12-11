import React, { useState, useEffect } from 'react';
import {
  Form,
  DatePicker,
  Select,
  InputNumber,
  Button,
  Table,
  message,
  Card,
  Row,
  Col,
  Space,
  Alert,
  Spin,
} from 'antd';
import { SaveOutlined, ReloadOutlined } from '@ant-design/icons';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { meterReadingsService } from '../services/meterReadingsService';
import { metersService } from '../services/metersService';
import { formatNumber, getMonthName } from '../utils/formatters';
import dayjs from 'dayjs';

const { Option } = Select;

const BatchMeterReadingForm = () => {
  const [form] = Form.useForm();
  const queryClient = useQueryClient();
  const [batchReadings, setBatchReadings] = useState({});
  const [validationErrors, setValidationErrors] = useState({});

  // Fetch all meters
  const { data: metersData, isLoading: metersLoading } = useQuery({
    queryKey: ['meters'],
    queryFn: () => metersService.getAll(),
  });

  // Fetch all meter readings to get previous readings
  const { data: readingsData, isLoading: readingsLoading } = useQuery({
    queryKey: ['meter-readings'],
    queryFn: () => meterReadingsService.getAll(),
  });

  const meters = metersData?.data || [];
  const readings = readingsData?.data || [];

  // Get previous reading for a specific meter
  const getPreviousReading = (meterId) => {
    const meterReadings = readings.filter(r => r.meter_id === meterId);
    if (meterReadings.length === 0) return null;

    const sortedReadings = [...meterReadings].sort((a, b) => {
      const dateA = new Date(a.reading_date);
      const dateB = new Date(b.reading_date);
      return dateB - dateA;
    });

    return sortedReadings[0];
  };

  // Calculate consumption
  const calculateConsumption = (currentValue, previousValue) => {
    if (currentValue == null || previousValue == null) return null;
    return currentValue - previousValue;
  };

  // Validate current reading value
  const validateReading = (meterId, value) => {
    if (value == null) return null;

    const previousReading = getPreviousReading(meterId);
    if (previousReading && value < previousReading.reading_value) {
      return `Valoarea trebuie să fie >= ${formatNumber(previousReading.reading_value)}`;
    }
    return null;
  };

  // Handle reading value change
  const handleReadingChange = (meterId, value) => {
    setBatchReadings(prev => ({
      ...prev,
      [meterId]: value,
    }));

    // Validate
    const error = validateReading(meterId, value);
    setValidationErrors(prev => ({
      ...prev,
      [meterId]: error,
    }));
  };

  // Batch create mutation
  const batchCreateMutation = useMutation({
    mutationFn: (readings) => {
      // If batch endpoint not available, fallback to individual creates
      if (readings.length === 0) {
        return Promise.reject(new Error('Nu există citiri de salvat'));
      }

      // Try batch endpoint first
      return meterReadingsService.createBatch(readings).catch(() => {
        // Fallback to individual creates
        return Promise.all(
          readings.map(reading => meterReadingsService.create(reading))
        );
      });
    },
    onSuccess: () => {
      message.success('Toate citirilе au fost salvate cu succes!');
      queryClient.invalidateQueries(['meter-readings']);
      // Reset form
      form.resetFields();
      setBatchReadings({});
      setValidationErrors({});
    },
    onError: (error) => {
      message.error(error.message || 'Eroare la salvarea citirilоr');
    },
  });

  // Handle form submit
  const handleSubmit = () => {
    form.validateFields().then((values) => {
      const { reading_date, period_month, period_year } = values;

      // Check if we have any readings
      const metersWithReadings = Object.keys(batchReadings).filter(
        meterId => batchReadings[meterId] != null
      );

      if (metersWithReadings.length === 0) {
        message.warning('Vă rugăm să introduceți cel puțin o citire');
        return;
      }

      // Check for validation errors
      const hasErrors = metersWithReadings.some(
        meterId => validationErrors[meterId] != null
      );

      if (hasErrors) {
        message.error('Vă rugăm să corectați erorile de validare');
        return;
      }

      // Build readings array
      const readingsToSave = metersWithReadings.map(meterId => ({
        meter_id: parseInt(meterId),
        reading_value: batchReadings[meterId],
        reading_date: reading_date.format('YYYY-MM-DD'),
        period_month,
        period_year,
      }));

      batchCreateMutation.mutate(readingsToSave);
    });
  };

  // Reset form
  const handleReset = () => {
    form.resetFields();
    setBatchReadings({});
    setValidationErrors({});
  };

  // Set default values - previous month
  useEffect(() => {
    const now = dayjs();
    const prevMonth = now.subtract(1, 'month');

    form.setFieldsValue({
      reading_date: now,
      period_month: prevMonth.month() + 1,
      period_year: prevMonth.year(),
    });
  }, [form]);

  // Table columns
  const columns = [
    {
      title: 'Nume Contor',
      dataIndex: 'name',
      key: 'name',
      width: 200,
      fixed: 'left',
    },
    {
      title: 'Număr Contor',
      dataIndex: 'meter_number',
      key: 'meter_number',
      width: 150,
    },
    {
      title: 'Tip',
      dataIndex: 'type',
      key: 'type',
      width: 100,
      render: (type) => {
        const typeLabels = {
          electric: 'Electric',
          gas: 'Gaze',
          water_cold: 'Apă Rece',
          water_hot: 'Apă Caldă',
          heating: 'Încălzire',
        };
        return typeLabels[type] || type;
      },
    },
    {
      title: 'Index Anterior',
      key: 'previous_reading',
      width: 120,
      render: (_, record) => {
        const previousReading = getPreviousReading(record.id);
        return previousReading ? formatNumber(previousReading.reading_value) : '-';
      },
    },
    {
      title: 'Index Curent',
      key: 'current_reading',
      width: 150,
      render: (_, record) => {
        const error = validationErrors[record.id];
        return (
          <div>
            <InputNumber
              min={0}
              precision={2}
              style={{ width: '100%' }}
              value={batchReadings[record.id]}
              onChange={(value) => handleReadingChange(record.id, value)}
              status={error ? 'error' : ''}
              placeholder="Introduceți"
            />
            {error && (
              <div style={{ color: '#ff4d4f', fontSize: 12, marginTop: 4 }}>
                {error}
              </div>
            )}
          </div>
        );
      },
    },
    {
      title: 'Consum',
      key: 'consumption',
      width: 100,
      render: (_, record) => {
        const currentValue = batchReadings[record.id];
        const previousReading = getPreviousReading(record.id);

        if (currentValue == null) return '-';

        const consumption = calculateConsumption(
          currentValue,
          previousReading?.reading_value
        );

        if (consumption == null) return '-';

        const color = consumption < 0 ? 'red' : consumption === 0 ? 'gray' : 'green';
        return <span style={{ color, fontWeight: 500 }}>{formatNumber(consumption)}</span>;
      },
    },
  ];

  const isLoading = metersLoading || readingsLoading;

  return (
    <div>
      <Card title="Date Generale" style={{ marginBottom: 16 }}>
        <Form form={form} layout="vertical">
          <Row gutter={16}>
            <Col xs={24} sm={8}>
              <Form.Item
                label="Data Citirii"
                name="reading_date"
                rules={[{ required: true, message: 'Data este obligatorie' }]}
              >
                <DatePicker
                  style={{ width: '100%' }}
                  format="DD.MM.YYYY"
                  placeholder="Selectați data"
                />
              </Form.Item>
            </Col>
            <Col xs={24} sm={8}>
              <Form.Item
                label="Luna"
                name="period_month"
                rules={[{ required: true, message: 'Luna este obligatorie' }]}
              >
                <Select placeholder="Selectați luna">
                  {Array.from({ length: 12 }, (_, i) => i + 1).map((month) => (
                    <Option key={month} value={month}>
                      {getMonthName(month)}
                    </Option>
                  ))}
                </Select>
              </Form.Item>
            </Col>
            <Col xs={24} sm={8}>
              <Form.Item
                label="Anul"
                name="period_year"
                rules={[{ required: true, message: 'Anul este obligatoriu' }]}
              >
                <InputNumber
                  min={2020}
                  max={2100}
                  style={{ width: '100%' }}
                  placeholder="Introduceți anul"
                />
              </Form.Item>
            </Col>
          </Row>
        </Form>
      </Card>

      <Card
        title="Citiri Contoare"
        extra={
          <Space>
            <Button
              icon={<ReloadOutlined />}
              onClick={handleReset}
              disabled={batchCreateMutation.isPending}
            >
              Resetează
            </Button>
            <Button
              type="primary"
              icon={<SaveOutlined />}
              onClick={handleSubmit}
              loading={batchCreateMutation.isPending}
            >
              Salvează Toate
            </Button>
          </Space>
        }
      >
        {isLoading ? (
          <div style={{ textAlign: 'center', padding: 40 }}>
            <Spin size="large" />
          </div>
        ) : (
          <>
            <Alert
              title="Instrucțiuni"
              description="Introduceți citirilе pentru contoarele dorite. Nu este necesar să completați toate contoarelе. Doar citirilе introduse vor fi salvate."
              type="info"
              showIcon
              style={{ marginBottom: 16 }}
            />
            <Table
              columns={columns}
              dataSource={meters}
              rowKey="id"
              pagination={false}
              scroll={{ x: 800 }}
              bordered
            />
          </>
        )}
      </Card>
    </div>
  );
};

export default BatchMeterReadingForm;
