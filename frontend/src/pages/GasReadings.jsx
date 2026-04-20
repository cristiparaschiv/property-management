import React, { useState } from 'react';
import {
  Table,
  Button,
  Space,
  Modal,
  Form,
  InputNumber,
  Select,
  DatePicker,
  Input,
  message,
  Card,
  Popconfirm,
  Row,
  Col,
} from 'antd';
import { PlusOutlined, EditOutlined, DeleteOutlined } from '@ant-design/icons';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { gasReadingsService } from '../services/gasReadingsService';
import { tenantsService } from '../services/tenantsService';
import { formatDate, formatNumber, getMonthName } from '../utils/formatters';
import dayjs from 'dayjs';

const { Option } = Select;
const { TextArea } = Input;

const GasReadings = () => {
  const [form] = Form.useForm();
  const queryClient = useQueryClient();
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingRecord, setEditingRecord] = useState(null);
  const [filterTenantId, setFilterTenantId] = useState(null);
  const [filterYear, setFilterYear] = useState(null);
  const [filterMonth, setFilterMonth] = useState(null);

  const { data: readingsData, isLoading } = useQuery({
    queryKey: ['gas-readings', filterTenantId, filterYear, filterMonth],
    queryFn: () => {
      const params = {};
      if (filterTenantId) params.tenant_id = filterTenantId;
      if (filterYear) params.period_year = filterYear;
      if (filterMonth) params.period_month = filterMonth;
      return gasReadingsService.getAll(params);
    },
  });

  const { data: tenantsData } = useQuery({
    queryKey: ['tenants'],
    queryFn: () => tenantsService.getAll(),
  });

  const createMutation = useMutation({
    mutationFn: (values) => gasReadingsService.create(values),
    onSuccess: () => {
      message.success('Index adăugat cu succes!');
      queryClient.invalidateQueries({ queryKey: ['gas-readings'] });
      setIsModalOpen(false);
      form.resetFields();
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la adăugare');
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, values }) => gasReadingsService.update(id, values),
    onSuccess: () => {
      message.success('Index actualizat cu succes!');
      queryClient.invalidateQueries({ queryKey: ['gas-readings'] });
      setIsModalOpen(false);
      setEditingRecord(null);
      form.resetFields();
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la actualizare');
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (id) => gasReadingsService.delete(id),
    onSuccess: () => {
      message.success('Index șters cu succes!');
      queryClient.invalidateQueries({ queryKey: ['gas-readings'] });
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la ștergere');
    },
  });

  const showCreateModal = () => {
    setEditingRecord(null);
    form.resetFields();
    setIsModalOpen(true);
  };

  const showEditModal = (record) => {
    setEditingRecord(record);
    form.setFieldsValue({
      tenant_id: record.tenant_id,
      period_year: record.period_year,
      period_month: record.period_month,
      reading_date: record.reading_date ? dayjs(record.reading_date) : null,
      reading_value: record.reading_value,
      notes: record.notes,
    });
    setIsModalOpen(true);
  };

  const handleOk = () => {
    form.validateFields().then((values) => {
      const payload = {
        ...values,
        reading_date: values.reading_date.format('YYYY-MM-DD'),
      };
      if (editingRecord) {
        updateMutation.mutate({ id: editingRecord.id, values: payload });
      } else {
        createMutation.mutate(payload);
      }
    });
  };

  const handleCancel = () => {
    setIsModalOpen(false);
    setEditingRecord(null);
    form.resetFields();
  };

  const columns = [
    {
      title: 'Chiriaș',
      dataIndex: 'tenant_name',
      key: 'tenant_name',
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
      title: 'Index (m³)',
      dataIndex: 'reading_value',
      key: 'reading_value',
      render: (value) => (value != null ? formatNumber(value) : '-'),
    },
    {
      title: 'Index Anterior',
      dataIndex: 'previous_reading_value',
      key: 'previous_reading_value',
      render: (value) => (value != null ? formatNumber(value) : '-'),
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
    {
      title: 'Note',
      dataIndex: 'notes',
      key: 'notes',
      ellipsis: true,
    },
    {
      title: 'Acțiuni',
      key: 'actions',
      render: (_, record) => (
        <Space>
          <Button
            type="link"
            icon={<EditOutlined />}
            onClick={() => showEditModal(record)}
          />
          <Popconfirm
            title="Sigur doriți să ștergeți acest index?"
            okText="Da"
            cancelText="Nu"
            onConfirm={() => deleteMutation.mutate(record.id)}
          >
            <Button type="link" danger icon={<DeleteOutlined />} />
          </Popconfirm>
        </Space>
      ),
    },
  ];

  const readings = readingsData?.data || [];
  const tenants = tenantsData?.data || [];

  const currentYear = new Date().getFullYear();
  const yearOptions = Array.from({ length: 11 }, (_, i) => currentYear - 5 + i);

  return (
    <div>
      <h1 style={{ marginBottom: 16 }}>Indexuri Gaz</h1>

      <Card style={{ marginBottom: 16 }}>
        <Row gutter={16}>
          <Col xs={24} sm={8}>
            <Select
              placeholder="Filtrează după chiriaș"
              allowClear
              style={{ width: '100%' }}
              value={filterTenantId}
              onChange={setFilterTenantId}
            >
              {tenants.map((tenant) => (
                <Option key={tenant.id} value={tenant.id}>
                  {tenant.name}
                </Option>
              ))}
            </Select>
          </Col>
          <Col xs={12} sm={8}>
            <Select
              placeholder="An"
              allowClear
              style={{ width: '100%' }}
              value={filterYear}
              onChange={setFilterYear}
            >
              {yearOptions.map((y) => (
                <Option key={y} value={y}>
                  {y}
                </Option>
              ))}
            </Select>
          </Col>
          <Col xs={12} sm={8}>
            <Select
              placeholder="Lună"
              allowClear
              style={{ width: '100%' }}
              value={filterMonth}
              onChange={setFilterMonth}
            >
              {Array.from({ length: 12 }, (_, i) => i + 1).map((m) => (
                <Option key={m} value={m}>
                  {getMonthName(m)}
                </Option>
              ))}
            </Select>
          </Col>
        </Row>
      </Card>

      <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 16 }}>
        <Button type="primary" icon={<PlusOutlined />} onClick={showCreateModal}>
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

      <Modal
        title={editingRecord ? 'Editare Index Gaz' : 'Adăugare Index Gaz'}
        open={isModalOpen}
        onOk={handleOk}
        onCancel={handleCancel}
        width={700}
        okText="Salvează"
        cancelText="Anulează"
        confirmLoading={createMutation.isPending || updateMutation.isPending}
      >
        <Form form={form} layout="vertical">
          <Form.Item
            label="Chiriaș"
            name="tenant_id"
            rules={[{ required: true, message: 'Chiriașul este obligatoriu' }]}
          >
            <Select placeholder="Selectați chiriașul">
              {tenants.map((tenant) => (
                <Option key={tenant.id} value={tenant.id}>
                  {tenant.name}
                </Option>
              ))}
            </Select>
          </Form.Item>

          <Row gutter={16}>
            <Col span={12}>
              <Form.Item
                label="An"
                name="period_year"
                rules={[{ required: true, message: 'Anul este obligatoriu' }]}
              >
                <InputNumber min={2020} max={2100} style={{ width: '100%' }} />
              </Form.Item>
            </Col>
            <Col span={12}>
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
            </Col>
          </Row>

          <Form.Item
            label="Data Citirii"
            name="reading_date"
            rules={[{ required: true, message: 'Data este obligatorie' }]}
          >
            <DatePicker style={{ width: '100%' }} format="DD.MM.YYYY" />
          </Form.Item>

          <Form.Item
            label="Valoare Index (m³)"
            name="reading_value"
            rules={[{ required: true, message: 'Valoarea este obligatorie' }]}
          >
            <InputNumber
              min={0}
              step={0.01}
              precision={2}
              style={{ width: '100%' }}
            />
          </Form.Item>

          <Form.Item label="Note" name="notes">
            <TextArea rows={3} />
          </Form.Item>
        </Form>
      </Modal>
    </div>
  );
};

export default GasReadings;
