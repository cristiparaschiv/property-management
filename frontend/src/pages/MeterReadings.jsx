import React, { useState, useEffect } from 'react';
import {
  Table,
  Button,
  Space,
  Modal,
  Form,
  InputNumber,
  Select,
  DatePicker,
  message,
  Card,
  Alert,
  Divider,
  Statistic,
  Row,
  Col,
  Tabs,
} from 'antd';
import { PlusOutlined, WarningOutlined, UnorderedListOutlined, AppstoreAddOutlined } from '@ant-design/icons';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { meterReadingsService } from '../services/meterReadingsService';
import { metersService } from '../services/metersService';
import { formatDate, formatNumber, getMonthName } from '../utils/formatters';
import BatchMeterReadingForm from '../components/BatchMeterReadingForm';
import dayjs from 'dayjs';

const { Option } = Select;

const MeterReadings = () => {
  const [form] = Form.useForm();
  const queryClient = useQueryClient();
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [selectedMeterId, setSelectedMeterId] = useState(null);
  const [previousReading, setPreviousReading] = useState(null);
  const [calculatedConsumption, setCalculatedConsumption] = useState(null);

  const { data: readingsData, isLoading } = useQuery({
    queryKey: ['meter-readings'],
    queryFn: () => meterReadingsService.getAll(),
  });

  const { data: metersData } = useQuery({
    queryKey: ['meters'],
    queryFn: () => metersService.getAll(),
  });

  const createMutation = useMutation({
    mutationFn: (values) => meterReadingsService.create(values),
    onSuccess: () => {
      message.success('Index adăugat cu succes!');
      queryClient.invalidateQueries(['meter-readings']);
      setIsModalOpen(false);
      form.resetFields();
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la adăugare');
    },
  });

  // Effect to fetch previous reading when meter is selected
  useEffect(() => {
    if (selectedMeterId && readingsData?.data) {
      const meterReadings = readingsData.data.filter(r => r.meter_id === selectedMeterId);
      if (meterReadings.length > 0) {
        // Get the most recent reading for this meter
        const sortedReadings = [...meterReadings].sort((a, b) => {
          const dateA = new Date(a.reading_date);
          const dateB = new Date(b.reading_date);
          return dateB - dateA;
        });
        setPreviousReading(sortedReadings[0]);
      } else {
        setPreviousReading(null);
      }
    } else {
      setPreviousReading(null);
    }
  }, [selectedMeterId, readingsData]);

  // Removed this useEffect as it was causing the warning about Form instance not being connected.
  // The consumption calculation is now handled only in the handleReadingValueChange function.

  const showCreateModal = () => {
    form.resetFields();
    setSelectedMeterId(null);
    setPreviousReading(null);
    setCalculatedConsumption(null);
    setIsModalOpen(true);
  };

  const handleMeterChange = (meterId) => {
    setSelectedMeterId(meterId);
    // Reset reading value and consumption when meter changes
    form.setFieldsValue({ reading_value: undefined });
    setCalculatedConsumption(null);
  };

  const handleReadingValueChange = (value) => {
    if (value != null && previousReading) {
      const consumption = value - previousReading.reading_value;
      setCalculatedConsumption(consumption);
    } else {
      setCalculatedConsumption(null);
    }
  };

  const handleOk = () => {
    form.validateFields().then((values) => {
      const payload = {
        ...values,
        reading_date: values.reading_date.format('YYYY-MM-DD'),
      };
      createMutation.mutate(payload);
    });
  };

  const columns = [
    {
      title: 'Contor',
      dataIndex: 'meter_name',
      key: 'meter_name',
    },
    {
      title: 'Perioadă',
      key: 'period',
      render: (_, record) => `${getMonthName(record.period_month)} ${record.period_year}`,
      sorter: (a, b) => (a.period_year * 12 + a.period_month) - (b.period_year * 12 + b.period_month),
    },
    {
      title: 'Data Citirii',
      dataIndex: 'reading_date',
      key: 'reading_date',
      render: (date) => formatDate(date),
      sorter: (a, b) => new Date(a.reading_date) - new Date(b.reading_date),
    },
    {
      title: 'Index Curent',
      dataIndex: 'reading_value',
      key: 'reading_value',
      render: (value) => value != null ? formatNumber(value) : '-',
    },
    {
      title: 'Consum',
      dataIndex: 'consumption',
      key: 'consumption',
      render: (value) => {
        if (value == null) return '-';
        const num = Number(value);
        const color = num < 0 ? 'red' : num === 0 ? 'gray' : 'inherit';
        return <span style={{ color }}>{formatNumber(num)}</span>;
      },
    },
  ];

  const readings = readingsData?.data || [];
  const meters = metersData?.data || [];

  const tabItems = [
    {
      key: 'list',
      label: (
        <span>
          <UnorderedListOutlined />
          Istoric Citiri
        </span>
      ),
      children: (
        <>
          <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 16 }}>
            <Button
              type="primary"
              icon={<PlusOutlined />}
              onClick={showCreateModal}
            >
              Adaugă Index
            </Button>
          </div>
          <Card>
            <Table
              columns={columns}
              dataSource={readings}
              rowKey="id"
              loading={isLoading}
              pagination={{ pageSize: 10 }}
            />
          </Card>
        </>
      ),
    },
    {
      key: 'batch',
      label: (
        <span>
          <AppstoreAddOutlined />
          Introducere în Lot
        </span>
      ),
      children: <BatchMeterReadingForm />,
    },
  ];

  return (
    <div>
      <h1 style={{ marginBottom: 16 }}>Indexuri Contoare</h1>

      <Tabs defaultActiveKey="batch" items={tabItems} />

      <Modal
        title="Adăugare Index"
        open={isModalOpen}
        onOk={handleOk}
        onCancel={() => {
          setIsModalOpen(false);
          form.resetFields();
          setSelectedMeterId(null);
          setPreviousReading(null);
          setCalculatedConsumption(null);
        }}
        width={700}
        okText="Salvează"
        cancelText="Anulează"
        confirmLoading={createMutation.isPending}
      >
        <Form form={form} layout="vertical">
          <Form.Item
            label="Contor"
            name="meter_id"
            rules={[{ required: true, message: 'Contorul este obligatoriu' }]}
          >
            <Select
              placeholder="Selectați contorul"
              onChange={handleMeterChange}
            >
              {meters.map((meter) => (
                <Option key={meter.id} value={meter.id}>
                  {meter.name}
                </Option>
              ))}
            </Select>
          </Form.Item>

          {selectedMeterId && !previousReading && (
            <Alert
              title="Atenție"
              description="Acesta este primul index pentru acest contor. Consumul va fi 0."
              type="warning"
              icon={<WarningOutlined />}
              showIcon
              style={{ marginBottom: 16 }}
            />
          )}

          {previousReading && (
            <Card
              size="small"
              style={{ marginBottom: 16, backgroundColor: '#f0f2f5' }}
            >
              <Row gutter={16}>
                <Col span={8}>
                  <Statistic
                    title="Index Anterior"
                    value={previousReading.reading_value}
                    precision={2}
                  />
                </Col>
                <Col span={8}>
                  <Statistic
                    title="Perioadă Anterioară"
                    value={`${getMonthName(previousReading.period_month)} ${previousReading.period_year}`}
                  />
                </Col>
                <Col span={8}>
                  <Statistic
                    title="Data Anterioară"
                    value={formatDate(previousReading.reading_date)}
                  />
                </Col>
              </Row>
            </Card>
          )}

          <Form.Item
            label="Data Citirii"
            name="reading_date"
            rules={[{ required: true, message: 'Data este obligatorie' }]}
          >
            <DatePicker style={{ width: '100%' }} format="DD.MM.YYYY" />
          </Form.Item>

          <Form.Item
            label="Valoare Index Curent"
            name="reading_value"
            rules={[
              { required: true, message: 'Valoarea este obligatorie' },
              {
                validator: (_, value) => {
                  if (value != null && previousReading && value < previousReading.reading_value) {
                    return Promise.reject(
                      new Error(`Valoarea trebuie să fie mai mare sau egală cu indexul anterior (${formatNumber(previousReading.reading_value)})`)
                    );
                  }
                  return Promise.resolve();
                },
              },
            ]}
          >
            <InputNumber
              min={0}
              style={{ width: '100%' }}
              onChange={handleReadingValueChange}
              precision={2}
            />
          </Form.Item>

          {calculatedConsumption != null && (
            <Alert
              title={`Consum Estimat: ${formatNumber(calculatedConsumption)}`}
              type={calculatedConsumption < 0 ? 'error' : 'info'}
              showIcon
              style={{ marginBottom: 16 }}
            />
          )}

          <Form.Item
            label="Lună"
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

          <Form.Item
            label="An"
            name="period_year"
            rules={[{ required: true, message: 'Anul este obligatoriu' }]}
          >
            <InputNumber min={2020} max={2100} style={{ width: '100%' }} />
          </Form.Item>
        </Form>
      </Modal>
    </div>
  );
};

export default MeterReadings;
