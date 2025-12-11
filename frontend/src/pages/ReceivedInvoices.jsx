import React, { useState, useRef } from 'react';
import {
  Table,
  Button,
  Space,
  Modal,
  Form,
  Input,
  InputNumber,
  Select,
  DatePicker,
  message,
  Popconfirm,
  Tag,
  Card,
  Dropdown,
  Typography,
} from 'antd';
import { PlusOutlined, EditOutlined, DeleteOutlined, CheckOutlined, MoreOutlined, SearchOutlined } from '@ant-design/icons';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { receivedInvoicesService } from '../services/receivedInvoicesService';
import { utilityProvidersService } from '../services/utilityProvidersService';
import { formatDate, formatCurrency } from '../utils/formatters';
import { UTILITY_TYPE_OPTIONS, getUtilityTypeLabel } from '../constants/utilityTypes';
import EmptyState from '../components/EmptyState';
import dayjs from 'dayjs';

const { Title } = Typography;

const { Option } = Select;

const ReceivedInvoices = () => {
  const [form] = Form.useForm();
  const queryClient = useQueryClient();
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingInvoice, setEditingInvoice] = useState(null);
  const searchInput = useRef(null);

  const { data: invoicesData, isLoading } = useQuery({
    queryKey: ['received-invoices'],
    queryFn: () => receivedInvoicesService.getAll(),
  });

  const { data: providersData } = useQuery({
    queryKey: ['utility-providers'],
    queryFn: () => utilityProvidersService.getAll(),
  });

  const createMutation = useMutation({
    mutationFn: (values) => receivedInvoicesService.create(values),
    onSuccess: () => {
      message.success('Factură adăugată cu succes!');
      queryClient.invalidateQueries(['received-invoices']);
      setIsModalOpen(false);
      form.resetFields();
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la adăugare');
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, values }) => receivedInvoicesService.update(id, values),
    onSuccess: () => {
      message.success('Factură actualizată cu succes!');
      queryClient.invalidateQueries(['received-invoices']);
      setIsModalOpen(false);
      setEditingInvoice(null);
      form.resetFields();
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la actualizare');
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (id) => receivedInvoicesService.delete(id),
    onSuccess: () => {
      message.success('Factură ștearsă cu succes!');
      queryClient.invalidateQueries(['received-invoices']);
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la ștergere');
    },
  });

  const markPaidMutation = useMutation({
    mutationFn: (id) => receivedInvoicesService.markPaidNow(id),
    onSuccess: () => {
      message.success('Factură marcată ca plătită!');
      queryClient.invalidateQueries(['received-invoices']);
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare');
    },
  });

  const showCreateModal = () => {
    setEditingInvoice(null);
    form.resetFields();
    setIsModalOpen(true);
  };

  const showEditModal = (invoice) => {
    setEditingInvoice(invoice);
    form.setFieldsValue({
      ...invoice,
      invoice_date: dayjs(invoice.invoice_date),
      due_date: dayjs(invoice.due_date),
      period_month: dayjs(invoice.period_start),
    });
    setIsModalOpen(true);
  };

  const handleOk = () => {
    form.validateFields().then((values) => {
      // Calculate period_start and period_end from the selected month
      const selectedMonth = values.period_month;
      const period_start = selectedMonth.startOf('month').format('YYYY-MM-DD');
      const period_end = selectedMonth.endOf('month').format('YYYY-MM-DD');

      const payload = {
        ...values,
        invoice_date: values.invoice_date.format('YYYY-MM-DD'),
        due_date: values.due_date.format('YYYY-MM-DD'),
        period_start,
        period_end,
      };

      // Remove period_month from payload as it's not needed by the API
      delete payload.period_month;

      if (editingInvoice) {
        updateMutation.mutate({ id: editingInvoice.id, values: payload });
      } else {
        createMutation.mutate(payload);
      }
    });
  };

  const getColumnSearchProps = (dataIndex, placeholder) => ({
    filterDropdown: ({ setSelectedKeys, selectedKeys, confirm, clearFilters }) => (
      <div style={{ padding: 8 }}>
        <Input
          ref={searchInput}
          placeholder={placeholder}
          value={selectedKeys[0]}
          onChange={(e) => setSelectedKeys(e.target.value ? [e.target.value] : [])}
          onPressEnter={() => confirm()}
          style={{ marginBottom: 8, display: 'block' }}
        />
        <Space>
          <Button
            type="primary"
            onClick={() => confirm()}
            icon={<SearchOutlined />}
            size="small"
            style={{ width: 90 }}
          >
            Caută
          </Button>
          <Button
            onClick={() => {
              clearFilters();
              confirm();
            }}
            size="small"
            style={{ width: 90 }}
          >
            Resetează
          </Button>
        </Space>
      </div>
    ),
    filterIcon: (filtered) => (
      <SearchOutlined style={{ color: filtered ? '#1890ff' : undefined }} />
    ),
    onFilter: (value, record) =>
      record[dataIndex]
        ?.toString()
        .toLowerCase()
        .includes(value.toLowerCase()),
    filterDropdownProps: {
      onOpenChange: (visible) => {
        if (visible) {
          setTimeout(() => searchInput.current?.select(), 100);
        }
      },
    },
  });

  const columns = [
    {
      title: 'Furnizor',
      dataIndex: 'provider_name',
      key: 'provider_name',
      ...getColumnSearchProps('provider_name', 'Caută după furnizor'),
    },
    {
      title: 'Nr. Factură',
      dataIndex: 'invoice_number',
      key: 'invoice_number',
      ...getColumnSearchProps('invoice_number', 'Caută după număr'),
    },
    {
      title: 'Data Facturii',
      dataIndex: 'invoice_date',
      key: 'invoice_date',
      render: (date) => formatDate(date),
      sorter: (a, b) => new Date(a.invoice_date) - new Date(b.invoice_date),
    },
    {
      title: 'Sumă',
      dataIndex: 'amount',
      key: 'amount',
      render: (amount) => formatCurrency(amount),
      sorter: (a, b) => a.amount - b.amount,
    },
    {
      title: 'Tip',
      dataIndex: 'utility_type',
      key: 'utility_type',
      render: (type) => getUtilityTypeLabel(type),
      filters: UTILITY_TYPE_OPTIONS.map(option => ({
        text: option.label,
        value: option.value,
      })),
      onFilter: (value, record) => record.utility_type === value,
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
      filters: [
        { text: 'Plătită', value: true },
        { text: 'Neplătită', value: false },
      ],
      onFilter: (value, record) => record.is_paid === value,
    },
    {
      title: 'Acțiuni',
      key: 'actions',
      render: (_, record) => {
        const items = [
          {
            key: 'edit',
            icon: <EditOutlined />,
            label: 'Editează',
            onClick: () => showEditModal(record),
          },
          ...(!record.is_paid ? [{
            key: 'mark-paid',
            icon: <CheckOutlined />,
            label: 'Plătită',
            onClick: () => markPaidMutation.mutate(record.id),
          }] : []),
          {
            key: 'delete',
            icon: <DeleteOutlined />,
            label: 'Șterge',
            danger: true,
            onClick: () => {
              Modal.confirm({
                title: 'Sigur doriți să ștergeți această factură?',
                onOk: () => deleteMutation.mutate(record.id),
                okText: 'Da',
                cancelText: 'Nu',
              });
            },
          },
        ];

        return (
          <Dropdown
            menu={{ items }}
            trigger={['click']}
          >
            <Button icon={<MoreOutlined />} />
          </Dropdown>
        );
      },
    },
  ];

  const invoices = invoicesData?.data || [];
  const providers = providersData?.data || [];

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
        <Title level={2} style={{ margin: 0 }}>Facturi Primite</Title>
        <Button
          type="primary"
          icon={<PlusOutlined />}
          onClick={showCreateModal}
        >
          Adaugă Factură
        </Button>
      </div>

      <Card>
        {invoices.length === 0 && !isLoading ? (
          <EmptyState
            description="Nu aveți facturi primite înregistrate. Adăugați prima factură de la furnizori."
            actionText="Adaugă Prima Factură"
            onAction={showCreateModal}
          />
        ) : (
          <Table
            columns={columns}
            dataSource={invoices}
            rowKey="id"
            loading={isLoading}
            pagination={{ pageSize: 10 }}
          />
        )}
      </Card>

      <Modal
        title={editingInvoice ? 'Editare Factură' : 'Adăugare Factură'}
        open={isModalOpen}
        onOk={handleOk}
        onCancel={() => {
          setIsModalOpen(false);
          setEditingInvoice(null);
          form.resetFields();
        }}
        width={700}
        okText="Salvează"
        cancelText="Anulează"
        confirmLoading={createMutation.isPending || updateMutation.isPending}
      >
        <Form form={form} layout="vertical">
          <Form.Item
            label="Furnizor"
            name="provider_id"
            rules={[{ required: true, message: 'Furnizorul este obligatoriu' }]}
          >
            <Select placeholder="Selectați furnizorul">
              {providers.map((provider) => (
                <Option key={provider.id} value={provider.id}>
                  {provider.name}
                </Option>
              ))}
            </Select>
          </Form.Item>

          <Form.Item
            label="Număr Factură"
            name="invoice_number"
            rules={[{ required: true, message: 'Numărul este obligatoriu' }]}
          >
            <Input />
          </Form.Item>

          <Form.Item
            label="Data Facturii"
            name="invoice_date"
            rules={[{ required: true, message: 'Data este obligatorie' }]}
          >
            <DatePicker style={{ width: '100%' }} format="DD.MM.YYYY" />
          </Form.Item>

          <Form.Item
            label="Data Scadență"
            name="due_date"
            rules={[{ required: true, message: 'Data scadență este obligatorie' }]}
          >
            <DatePicker style={{ width: '100%' }} format="DD.MM.YYYY" />
          </Form.Item>

          <Form.Item
            label="Sumă"
            name="amount"
            rules={[{ required: true, message: 'Suma este obligatorie' }]}
          >
            <InputNumber min={0} style={{ width: '100%' }} />
          </Form.Item>

          <Form.Item
            label="Tip Utilitate"
            name="utility_type"
            rules={[{ required: true, message: 'Tipul este obligatoriu' }]}
          >
            <Select>
              {UTILITY_TYPE_OPTIONS.map((option) => (
                <Option key={option.value} value={option.value}>
                  {option.label}
                </Option>
              ))}
            </Select>
          </Form.Item>

          <Form.Item
            label="Perioadă (Lună/An)"
            name="period_month"
            rules={[{ required: true, message: 'Luna este obligatorie' }]}
          >
            <DatePicker picker="month" style={{ width: '100%' }} format="MMMM YYYY" placeholder="Selectați luna" />
          </Form.Item>
        </Form>
      </Modal>
    </div>
  );
};

export default ReceivedInvoices;
