import React, { useState, useEffect, useRef } from 'react';
import {
  Table,
  Button,
  Space,
  Modal,
  Form,
  Select,
  DatePicker,
  message,
  Tag,
  Card,
  Popconfirm,
  Dropdown,
  InputNumber,
  Input,
  Divider,
  Alert,
  Row,
  Col,
  Radio,
  Typography,
  Spin,
  Tooltip,
} from 'antd';
import {
  PlusOutlined,
  FilePdfOutlined,
  CheckOutlined,
  DeleteOutlined,
  MoreOutlined,
  MinusCircleOutlined,
  SearchOutlined,
  InfoCircleOutlined,
} from '@ant-design/icons';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { invoicesService } from '../services/invoicesService';
import { tenantsService } from '../services/tenantsService';
import { exchangeRatesService } from '../services/exchangeRatesService';
import { formatDate, formatCurrency } from '../utils/formatters';
import EmptyState from '../components/EmptyState';
import dayjs from 'dayjs';

const { Title } = Typography;

const { Option } = Select;
const { TextArea } = Input;

const Invoices = () => {
  const [form] = Form.useForm();
  const queryClient = useQueryClient();
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [invoiceType, setInvoiceType] = useState('rent');
  const [exchangeRate, setExchangeRate] = useState(null);
  const [exchangeRateDate, setExchangeRateDate] = useState(null);
  const [exchangeRateIsFallback, setExchangeRateIsFallback] = useState(false);
  const [exchangeRateError, setExchangeRateError] = useState(false);
  const [additionalServices, setAdditionalServices] = useState([]);
  const [lineItems, setLineItems] = useState([]);
  const [clientType, setClientType] = useState('tenant');
  const searchInput = useRef(null);

  const { data: invoicesData, isLoading } = useQuery({
    queryKey: ['invoices'],
    queryFn: () => invoicesService.getAll(),
  });

  const { data: tenantsData } = useQuery({
    queryKey: ['tenants'],
    queryFn: () => tenantsService.getAll(),
  });

  const createRentMutation = useMutation({
    mutationFn: (values) => invoicesService.createRent(values),
    onSuccess: () => {
      message.success('Factură chirie creată cu succes!');
      queryClient.invalidateQueries(['invoices']);
      setIsModalOpen(false);
      form.resetFields();
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la creare');
    },
  });

  const createGenericMutation = useMutation({
    mutationFn: (values) => invoicesService.createGeneric(values),
    onSuccess: () => {
      message.success('Factură generică creată cu succes!');
      queryClient.invalidateQueries(['invoices']);
      setIsModalOpen(false);
      form.resetFields();
      setLineItems([]);
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la creare');
    },
  });

  const markPaidMutation = useMutation({
    mutationFn: ({ id, paidDate }) => invoicesService.markPaid(id, paidDate),
    onSuccess: () => {
      message.success('Factură marcată ca plătită!');
      queryClient.invalidateQueries(['invoices']);
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare');
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (id) => invoicesService.delete(id),
    onSuccess: () => {
      message.success('Factură ștearsă cu succes!');
      queryClient.invalidateQueries(['invoices']);
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la ștergere');
    },
  });

  const handleDownloadPDF = async (id, invoiceNumber) => {
    try {
      const blob = await invoicesService.downloadPDF(id);
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `${invoiceNumber}.pdf`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);
    } catch (error) {
      message.error('Eroare la descărcarea PDF-ului');
    }
  };

  const fetchExchangeRate = async (date) => {
    try {
      setExchangeRateError(false);
      setExchangeRateIsFallback(false);
      setExchangeRateDate(null);
      const formattedDate = date ? dayjs(date).format('YYYY-MM-DD') : dayjs().format('YYYY-MM-DD');
      const response = await exchangeRatesService.getByDate(formattedDate);
      if (response.data?.exchange_rate?.rate) {
        const rateData = response.data.exchange_rate;
        setExchangeRate(rateData.rate);
        setExchangeRateDate(rateData.date);
        setExchangeRateIsFallback(rateData.is_fallback === 1);
        form.setFieldsValue({ exchange_rate: rateData.rate });
      } else {
        setExchangeRateError(true);
        setExchangeRate(null);
        setExchangeRateDate(null);
      }
    } catch (error) {
      setExchangeRateError(true);
      setExchangeRate(null);
      setExchangeRateDate(null);
      console.error('Error fetching exchange rate:', error);
    }
  };

  const showCreateModal = (type) => {
    setInvoiceType(type);
    form.resetFields();
    setAdditionalServices([]);
    setLineItems([]);
    setExchangeRate(null);
    setExchangeRateDate(null);
    setExchangeRateIsFallback(false);
    setExchangeRateError(false);
    setClientType('tenant');

    // Set default month and year to current (for rent invoices)
    const now = dayjs();
    if (type === 'rent') {
      form.setFieldsValue({
        month: now.month() + 1, // dayjs months are 0-indexed
        year: now.year(),
      });
      // Fetch exchange rate for rent invoices
      fetchExchangeRate(now);
    }

    // Set default dates for generic invoices
    if (type === 'generic') {
      form.setFieldsValue({
        invoice_date: now,
        due_date: now.add(15, 'days'),
      });
    }

    setIsModalOpen(true);
  };

  const handleAddService = () => {
    setAdditionalServices([
      ...additionalServices,
      {
        id: Date.now(),
        description: '',
        quantity: 1,
        unit_price: 0,
        vat_rate: 0,
      },
    ]);
  };

  const handleRemoveService = (id) => {
    setAdditionalServices(additionalServices.filter((s) => s.id !== id));
  };

  const handleServiceChange = (id, field, value) => {
    setAdditionalServices(
      additionalServices.map((s) => (s.id === id ? { ...s, [field]: value } : s))
    );
  };

  const handleAddLineItem = () => {
    setLineItems([
      ...lineItems,
      {
        id: Date.now(),
        description: '',
        quantity: 1,
        unit_price: 0,
        vat_rate: 0,
      },
    ]);
  };

  const handleRemoveLineItem = (id) => {
    setLineItems(lineItems.filter((item) => item.id !== id));
  };

  const handleLineItemChange = (id, field, value) => {
    setLineItems(
      lineItems.map((item) => (item.id === id ? { ...item, [field]: value } : item))
    );
  };

  const calculateGrandTotal = () => {
    return lineItems.reduce((total, item) => {
      const subtotal = item.quantity * item.unit_price;
      const vatAmount = subtotal * (item.vat_rate / 100);
      return total + subtotal + vatAmount;
    }, 0);
  };

  const handleOk = () => {
    form.validateFields().then((values) => {
      if (invoiceType === 'generic') {
        // Validate that at least one line item exists
        if (lineItems.length === 0) {
          message.error('Trebuie să adăugați cel puțin un articol');
          return;
        }

        const payload = {
          invoice_date: values.invoice_date?.format('YYYY-MM-DD'),
          due_date: values.due_date?.format('YYYY-MM-DD'),
          notes: values.notes || null,
        };

        // Add client info based on type
        if (clientType === 'tenant') {
          payload.tenant_id = values.tenant_id;
        } else {
          payload.client_name = values.client_name;
          payload.client_address = values.client_address || null;
          payload.client_tax_id = values.client_tax_id || null;
        }

        // Add items
        payload.items = lineItems.map((item) => ({
          description: item.description,
          quantity: item.quantity,
          unit_price: item.unit_price,
          vat_rate: item.vat_rate,
        }));

        createGenericMutation.mutate(payload);
      } else if (invoiceType === 'rent') {
        const payload = {
          tenant_id: values.tenant_id,
          invoice_date: values.invoice_date?.format('YYYY-MM-DD'),
          due_date: values.due_date?.format('YYYY-MM-DD'),
        };

        // Add month and year for description
        payload.period_month = values.month;
        payload.period_year = values.year;

        // Add exchange rate (from auto-fetch or manual input)
        if (values.exchange_rate) {
          payload.exchange_rate = values.exchange_rate;
        }

        // Add additional services if any
        if (additionalServices.length > 0) {
          payload.additional_items = additionalServices.map((s) => ({
            description: s.description,
            quantity: s.quantity,
            unit_price: s.unit_price,
            vat_rate: s.vat_rate,
          }));
        }

        createRentMutation.mutate(payload);
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
      title: 'Nr. Factură',
      dataIndex: 'invoice_number',
      key: 'invoice_number',
      sorter: (a, b) => a.invoice_number.localeCompare(b.invoice_number),
      ...getColumnSearchProps('invoice_number', 'Caută după număr'),
    },
    {
      title: 'Chiriaș',
      dataIndex: 'tenant_name',
      key: 'tenant_name',
      ...getColumnSearchProps('tenant_name', 'Caută după chiriaș'),
    },
    {
      title: 'Tip',
      dataIndex: 'invoice_type',
      key: 'invoice_type',
      render: (type) => {
        const typeConfig = {
          rent: { color: 'blue', label: 'Chirie' },
          utility: { color: 'green', label: 'Utilități' },
          generic: { color: 'purple', label: 'Generică' },
        };
        const config = typeConfig[type] || { color: 'default', label: type };
        return <Tag color={config.color}>{config.label}</Tag>;
      },
      filters: [
        { text: 'Chirie', value: 'rent' },
        { text: 'Utilități', value: 'utility' },
        { text: 'Generică', value: 'generic' },
      ],
      onFilter: (value, record) => record.invoice_type === value,
    },
    {
      title: 'Data',
      dataIndex: 'invoice_date',
      key: 'invoice_date',
      render: (date) => formatDate(date),
      sorter: (a, b) => new Date(a.invoice_date) - new Date(b.invoice_date),
    },
    {
      title: 'Total',
      dataIndex: 'total_amount',
      key: 'total_amount',
      render: (amount) => formatCurrency(amount),
      sorter: (a, b) => a.total_amount - b.total_amount,
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
            key: 'pdf',
            icon: <FilePdfOutlined />,
            label: 'Descarcă PDF',
            onClick: () => handleDownloadPDF(record.id, record.invoice_number),
          },
          ...(!record.is_paid ? [{
            key: 'mark-paid',
            icon: <CheckOutlined />,
            label: 'Plătită',
            onClick: () => markPaidMutation.mutate({ id: record.id, paidDate: dayjs().format('YYYY-MM-DD') }),
          }] : []),
          ...(!record.is_paid ? [{
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
          }] : []),
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

  const invoices = invoicesData?.data?.invoices || [];
  const tenants = tenantsData?.data?.tenants || [];

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
        <Title level={2} style={{ margin: 0 }}>Facturi Emise</Title>
        <Space>
          <Tooltip title="Creați o factură de chirie pentru un chiriaș cu conversie automată EUR→RON">
            <Button
              type="primary"
              icon={<PlusOutlined />}
              onClick={() => showCreateModal('rent')}
            >
              Factură Chirie
            </Button>
          </Tooltip>
          <Tooltip title="Creați o factură generică pentru orice serviciu sau produs">
            <Button
              type="primary"
              icon={<PlusOutlined />}
              onClick={() => showCreateModal('generic')}
              style={{ backgroundColor: '#722ed1', borderColor: '#722ed1' }}
            >
              Factură Generică
            </Button>
          </Tooltip>
        </Space>
      </div>

      <Card>
        {invoices.length === 0 && !isLoading ? (
          <EmptyState
            description="Nu aveți facturi emise. Creați prima factură de chirie sau factură generică."
            actionText="Creează Prima Factură"
            onAction={() => showCreateModal('rent')}
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
        title={
          invoiceType === 'rent'
            ? 'Creare Factură Chirie'
            : 'Creare Factură Generică'
        }
        open={isModalOpen}
        onOk={handleOk}
        onCancel={() => {
          setIsModalOpen(false);
          form.resetFields();
          setAdditionalServices([]);
          setLineItems([]);
          setExchangeRate(null);
          setExchangeRateError(false);
          setClientType('tenant');
        }}
        width={700}
        okText="Creează"
        cancelText="Anulează"
        confirmLoading={createRentMutation.isPending || createGenericMutation.isPending}
      >
        {(createRentMutation.isPending || createGenericMutation.isPending) && (
          <div style={{ textAlign: 'center', padding: '20px 0' }}>
            <Spin size="large" />
            <div style={{ marginTop: 16 }}>Se creează factura...</div>
          </div>
        )}
        <Form form={form} layout="vertical">
          {invoiceType === 'generic' && (
            <>
              <Row gutter={16}>
                <Col span={12}>
                  <Form.Item
                    label="Data Emiterii"
                    name="invoice_date"
                    rules={[{ required: true, message: 'Data emiterii este obligatorie' }]}
                  >
                    <DatePicker style={{ width: '100%' }} format="DD.MM.YYYY" />
                  </Form.Item>
                </Col>
                <Col span={12}>
                  <Form.Item
                    label="Data Scadentă"
                    name="due_date"
                    rules={[{ required: true, message: 'Data scadentă este obligatorie' }]}
                  >
                    <DatePicker style={{ width: '100%' }} format="DD.MM.YYYY" />
                  </Form.Item>
                </Col>
              </Row>

              <Form.Item label="Note" name="notes">
                <TextArea
                  rows={3}
                  placeholder="Note opționale pentru factură"
                />
              </Form.Item>

              <Divider orientation="left">Informații Client</Divider>

              <Form.Item label="Tip Client">
                <Radio.Group
                  value={clientType}
                  onChange={(e) => {
                    setClientType(e.target.value);
                    // Clear related fields when switching
                    if (e.target.value === 'tenant') {
                      form.setFieldsValue({
                        client_name: undefined,
                        client_address: undefined,
                        client_tax_id: undefined,
                      });
                    } else {
                      form.setFieldsValue({ tenant_id: undefined });
                    }
                  }}
                >
                  <Radio value="tenant">Chiriaș</Radio>
                  <Radio value="custom">Client Personalizat</Radio>
                </Radio.Group>
              </Form.Item>

              {clientType === 'tenant' ? (
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
              ) : (
                <>
                  <Form.Item
                    label="Nume Client"
                    name="client_name"
                    rules={[{ required: true, message: 'Numele clientului este obligatoriu' }]}
                  >
                    <Input placeholder="ex: SC Example SRL" />
                  </Form.Item>
                  <Form.Item label="Adresă Client" name="client_address">
                    <Input placeholder="ex: Str. Exemplu nr. 1, București" />
                  </Form.Item>
                  <Form.Item label="CUI/CNP Client" name="client_tax_id">
                    <Input placeholder="ex: RO12345678" />
                  </Form.Item>
                </>
              )}

              <Divider orientation="left">Articole Factură</Divider>

              {lineItems.map((item, index) => (
                <Card
                  key={item.id}
                  size="small"
                  style={{ marginBottom: 12 }}
                  extra={
                    <Button
                      type="text"
                      danger
                      icon={<MinusCircleOutlined />}
                      onClick={() => handleRemoveLineItem(item.id)}
                    >
                      Șterge
                    </Button>
                  }
                  title={`Articol ${index + 1}`}
                >
                  <Row gutter={8}>
                    <Col span={24}>
                      <Form.Item label="Descriere" style={{ marginBottom: 8 }}>
                        <Input
                          value={item.description}
                          onChange={(e) =>
                            handleLineItemChange(item.id, 'description', e.target.value)
                          }
                          placeholder="ex: Servicii consultanță"
                        />
                      </Form.Item>
                    </Col>
                    <Col span={8}>
                      <Form.Item label="Cantitate" style={{ marginBottom: 8 }}>
                        <InputNumber
                          style={{ width: '100%' }}
                          min={0}
                          value={item.quantity}
                          onChange={(value) =>
                            handleLineItemChange(item.id, 'quantity', value)
                          }
                        />
                      </Form.Item>
                    </Col>
                    <Col span={8}>
                      <Form.Item label="Preț Unitar" style={{ marginBottom: 8 }}>
                        <InputNumber
                          style={{ width: '100%' }}
                          step={0.01}
                          value={item.unit_price}
                          onChange={(value) =>
                            handleLineItemChange(item.id, 'unit_price', value)
                          }
                          placeholder="RON (negativ pt. discount)"
                        />
                      </Form.Item>
                    </Col>
                    <Col span={8}>
                      <Form.Item label="TVA %" style={{ marginBottom: 8 }}>
                        <InputNumber
                          style={{ width: '100%' }}
                          min={0}
                          max={100}
                          value={item.vat_rate}
                          onChange={(value) =>
                            handleLineItemChange(item.id, 'vat_rate', value)
                          }
                        />
                      </Form.Item>
                    </Col>
                  </Row>
                  <div style={{ textAlign: 'right', marginTop: 8 }}>
                    <div>
                      <strong>Subtotal: </strong>
                      {(item.quantity * item.unit_price).toFixed(2)} RON
                    </div>
                    <div>
                      <strong>TVA ({item.vat_rate}%): </strong>
                      {((item.quantity * item.unit_price * item.vat_rate) / 100).toFixed(2)} RON
                    </div>
                    <div style={{ fontSize: '16px', marginTop: 4 }}>
                      <strong>Total: </strong>
                      {(
                        item.quantity * item.unit_price +
                        (item.quantity * item.unit_price * item.vat_rate) / 100
                      ).toFixed(2)}{' '}
                      RON
                    </div>
                  </div>
                </Card>
              ))}

              <Button
                type="dashed"
                onClick={handleAddLineItem}
                block
                icon={<PlusOutlined />}
                style={{ marginBottom: 16 }}
              >
                Adaugă Articol
              </Button>

              {lineItems.length > 0 && (
                <Alert
                  message={
                    <div style={{ fontSize: '18px' }}>
                      <strong>Total General: {calculateGrandTotal().toFixed(2)} RON</strong>
                    </div>
                  }
                  type="info"
                  showIcon
                />
              )}
            </>
          )}

          {invoiceType === 'rent' && (
            <>
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
                    label="Luna"
                    name="month"
                    rules={[{ required: true, message: 'Luna este obligatorie' }]}
                  >
                    <Select placeholder="Selectați luna">
                      {[
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
                      ].map((month) => (
                        <Option key={month.value} value={month.value}>
                          {month.label}
                        </Option>
                      ))}
                    </Select>
                  </Form.Item>
                </Col>
                <Col span={12}>
                  <Form.Item
                    label="Anul"
                    name="year"
                    rules={[{ required: true, message: 'Anul este obligatoriu' }]}
                  >
                    <InputNumber
                      style={{ width: '100%' }}
                      min={2000}
                      max={2100}
                      placeholder="ex: 2025"
                    />
                  </Form.Item>
                </Col>
              </Row>

              <Form.Item
                label="Data Facturii"
                name="invoice_date"
                initialValue={dayjs()}
              >
                <DatePicker
                  style={{ width: '100%' }}
                  format="DD.MM.YYYY"
                  onChange={(date) => {
                    fetchExchangeRate(date);
                  }}
                />
              </Form.Item>

              <Form.Item
                label="Data Scadență"
                name="due_date"
                initialValue={dayjs().add(14, 'days')}
              >
                <DatePicker style={{ width: '100%' }} format="DD.MM.YYYY" />
              </Form.Item>

              <Form.Item
                label="Curs Valutar EUR/RON"
                name="exchange_rate"
                rules={[
                  { required: true, message: 'Cursul valutar este obligatoriu' },
                ]}
              >
                <InputNumber
                  style={{ width: '100%' }}
                  min={0}
                  step={0.0001}
                  precision={4}
                  placeholder="ex: 4.9750"
                  disabled={!exchangeRateError && exchangeRate !== null}
                />
              </Form.Item>

              {exchangeRateError && (
                <Alert
                  message="Cursul BNR nu este disponibil pentru această dată. Introduceți manual."
                  description="Pentru date în trecut sau viitor (diferență mai mare de 1 zi), cursul trebuie introdus manual."
                  type="warning"
                  showIcon
                  style={{ marginBottom: 16 }}
                />
              )}

              {!exchangeRateError && exchangeRate !== null && exchangeRateIsFallback && (
                <Alert
                  message={`Curs BNR preluat automat: ${Number(exchangeRate).toFixed(4)} (din ${exchangeRateDate})`}
                  description="Cursul pentru data solicitată nu este disponibil. Se folosește cel mai recent curs (diferență max 1 zi)."
                  type="info"
                  showIcon
                  style={{ marginBottom: 16 }}
                />
              )}

              {!exchangeRateError && exchangeRate !== null && !exchangeRateIsFallback && (
                <Alert
                  message={`Curs BNR preluat automat: ${Number(exchangeRate).toFixed(4)} (din ${exchangeRateDate})`}
                  type="success"
                  showIcon
                  style={{ marginBottom: 16 }}
                />
              )}

              <Divider orientation="left">Servicii Adiționale</Divider>

              {additionalServices.map((service) => (
                <Card
                  key={service.id}
                  size="small"
                  style={{ marginBottom: 12 }}
                  extra={
                    <Button
                      type="text"
                      danger
                      icon={<MinusCircleOutlined />}
                      onClick={() => handleRemoveService(service.id)}
                    >
                      Șterge
                    </Button>
                  }
                >
                  <Row gutter={8}>
                    <Col span={24}>
                      <Form.Item label="Descriere" style={{ marginBottom: 8 }}>
                        <Input
                          value={service.description}
                          onChange={(e) =>
                            handleServiceChange(service.id, 'description', e.target.value)
                          }
                          placeholder="ex: Curățenie scară bloc"
                        />
                      </Form.Item>
                    </Col>
                    <Col span={8}>
                      <Form.Item label="Cantitate" style={{ marginBottom: 8 }}>
                        <InputNumber
                          style={{ width: '100%' }}
                          min={0}
                          value={service.quantity}
                          onChange={(value) =>
                            handleServiceChange(service.id, 'quantity', value)
                          }
                        />
                      </Form.Item>
                    </Col>
                    <Col span={8}>
                      <Form.Item label="Preț Unitar" style={{ marginBottom: 8 }}>
                        <InputNumber
                          style={{ width: '100%' }}
                          step={0.01}
                          value={service.unit_price}
                          onChange={(value) =>
                            handleServiceChange(service.id, 'unit_price', value)
                          }
                          placeholder="RON (negativ pt. discount)"
                        />
                      </Form.Item>
                    </Col>
                    <Col span={8}>
                      <Form.Item label="TVA %" style={{ marginBottom: 8 }}>
                        <InputNumber
                          style={{ width: '100%' }}
                          min={0}
                          max={100}
                          value={service.vat_rate}
                          onChange={(value) =>
                            handleServiceChange(service.id, 'vat_rate', value)
                          }
                        />
                      </Form.Item>
                    </Col>
                  </Row>
                  <div style={{ textAlign: 'right', marginTop: 8 }}>
                    <strong>
                      Total:{' '}
                      {(service.quantity * service.unit_price).toFixed(2)} RON
                    </strong>
                  </div>
                </Card>
              ))}

              <Button
                type="dashed"
                onClick={handleAddService}
                block
                icon={<PlusOutlined />}
              >
                Adaugă Serviciu
              </Button>
            </>
          )}
        </Form>
      </Modal>
    </div>
  );
};

export default Invoices;
