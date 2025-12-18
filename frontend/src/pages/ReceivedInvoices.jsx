import React, { useState, useMemo } from 'react';
import {
  Button,
  Modal,
  Form,
  Input,
  InputNumber,
  Select,
  DatePicker,
  message,
  Tag,
  Spin,
  Dropdown,
  Tooltip,
} from 'antd';
import {
  PlusOutlined,
  EditOutlined,
  DeleteOutlined,
  CheckOutlined,
  FileTextOutlined,
  CheckCircleOutlined,
  CloseCircleOutlined,
  EuroOutlined,
  CalendarOutlined,
  ShopOutlined,
  NumberOutlined,
  HistoryOutlined,
} from '@ant-design/icons';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { receivedInvoicesService } from '../services/receivedInvoicesService';
import { utilityProvidersService } from '../services/utilityProvidersService';
import { formatDate, formatCurrency } from '../utils/formatters';
import { UTILITY_TYPE_OPTIONS, getUtilityTypeLabel } from '../constants/utilityTypes';
import EmptyState from '../components/EmptyState';
import CardRow, {
  CardRowPrimary,
  CardRowTitle,
  CardRowSecondary,
  CardRowDetail,
  ActionButton,
} from '../components/ui/CardRow';
import {
  ListSummaryCards,
  SummaryCard,
  ListPageHeader,
  ListToolbar,
} from '../components/ui/ListSummaryCards';
import dayjs from 'dayjs';

const { Option } = Select;

const ReceivedInvoices = () => {
  const [form] = Form.useForm();
  const queryClient = useQueryClient();
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingInvoice, setEditingInvoice] = useState(null);
  const [searchText, setSearchText] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [typeFilter, setTypeFilter] = useState('all');
  const [paidDateModalOpen, setPaidDateModalOpen] = useState(false);
  const [selectedInvoiceForPayment, setSelectedInvoiceForPayment] = useState(null);
  const [selectedPaidDate, setSelectedPaidDate] = useState(null);

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
    mutationFn: ({ id, paidDate }) => {
      if (paidDate) {
        return receivedInvoicesService.markPaid(id, paidDate);
      }
      return receivedInvoicesService.markPaidNow(id);
    },
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

      delete payload.period_month;

      if (editingInvoice) {
        updateMutation.mutate({ id: editingInvoice.id, values: payload });
      } else {
        createMutation.mutate(payload);
      }
    });
  };

  const handleDelete = (invoice) => {
    Modal.confirm({
      title: 'Sigur doriți să ștergeți această factură?',
      content: `Factura "${invoice.invoice_number}" va fi ștearsă permanent.`,
      onOk: () => deleteMutation.mutate(invoice.id),
      okText: 'Da, șterge',
      cancelText: 'Anulează',
      okButtonProps: { danger: true },
    });
  };

  const handleMarkPaidWithDate = (invoice) => {
    setSelectedInvoiceForPayment(invoice);
    setSelectedPaidDate(dayjs());
    setPaidDateModalOpen(true);
  };

  const handleConfirmPaidDate = () => {
    if (selectedInvoiceForPayment && selectedPaidDate) {
      markPaidMutation.mutate({
        id: selectedInvoiceForPayment.id,
        paidDate: selectedPaidDate.format('YYYY-MM-DD'),
      });
      setPaidDateModalOpen(false);
      setSelectedInvoiceForPayment(null);
      setSelectedPaidDate(null);
    }
  };

  const getPaymentMenuItems = (invoice) => [
    {
      key: 'now',
      label: 'Plătită Azi',
      icon: <CheckOutlined />,
      onClick: () => markPaidMutation.mutate({ id: invoice.id }),
    },
    {
      key: 'custom',
      label: 'Alege Data',
      icon: <HistoryOutlined />,
      onClick: () => handleMarkPaidWithDate(invoice),
    },
  ];

  const invoices = invoicesData?.data || [];
  const providers = providersData?.data || [];

  // Calculate summary stats
  const stats = useMemo(() => {
    const total = invoices.length;
    const paid = invoices.filter((i) => i.is_paid).length;
    const unpaid = invoices.filter((i) => !i.is_paid).length;
    const totalAmount = invoices.reduce((sum, i) => sum + (parseFloat(i.amount) || 0), 0);
    const unpaidAmount = invoices
      .filter((i) => !i.is_paid)
      .reduce((sum, i) => sum + (parseFloat(i.amount) || 0), 0);
    return { total, paid, unpaid, totalAmount, unpaidAmount };
  }, [invoices]);

  // Filter invoices
  const filteredInvoices = useMemo(() => {
    return invoices.filter((invoice) => {
      const matchesSearch =
        !searchText ||
        invoice.provider_name?.toLowerCase().includes(searchText.toLowerCase()) ||
        invoice.invoice_number?.toLowerCase().includes(searchText.toLowerCase());

      const matchesStatus =
        statusFilter === 'all' ||
        (statusFilter === 'paid' && invoice.is_paid) ||
        (statusFilter === 'unpaid' && !invoice.is_paid);

      const matchesType =
        typeFilter === 'all' || invoice.utility_type === typeFilter;

      return matchesSearch && matchesStatus && matchesType;
    });
  }, [invoices, searchText, statusFilter, typeFilter]);

  // Get row status based on invoice state
  const getRowStatus = (invoice) => {
    if (invoice.is_paid) return 'success';
    const dueDate = dayjs(invoice.due_date);
    const today = dayjs();
    if (dueDate.isBefore(today)) return 'error';
    if (dueDate.diff(today, 'day') <= 7) return 'warning';
    return 'default';
  };

  // Get utility type tag color
  const getTypeColor = (type) => {
    const colors = {
      electricity: 'gold',
      gas: 'orange',
      water: 'blue',
      internet: 'purple',
      salubrity: 'green',
      other: 'default',
    };
    return colors[type] || 'default';
  };

  return (
    <div>
      <ListPageHeader
        title="Facturi Primite"
        subtitle="Gestionează facturile primite de la furnizori"
        action={
          <Button type="primary" icon={<PlusOutlined />} onClick={showCreateModal}>
            Adaugă Factură
          </Button>
        }
      />

      <ListSummaryCards>
        <SummaryCard
          icon={<FileTextOutlined />}
          value={stats.total}
          label="Total Facturi"
          variant="default"
        />
        <SummaryCard
          icon={<CheckCircleOutlined />}
          value={stats.paid}
          label="Plătite"
          variant="success"
        />
        <SummaryCard
          icon={<CloseCircleOutlined />}
          value={stats.unpaid}
          label="Neplătite"
          variant="error"
          subValue={stats.unpaidAmount > 0 ? formatCurrency(stats.unpaidAmount) : null}
        />
        <SummaryCard
          icon={<EuroOutlined />}
          value={formatCurrency(stats.totalAmount)}
          label="Valoare Totală"
          variant="info"
        />
      </ListSummaryCards>

      <ListToolbar>
        <Input.Search
          placeholder="Caută după furnizor sau număr factură..."
          allowClear
          onChange={(e) => setSearchText(e.target.value)}
          style={{ maxWidth: 320 }}
        />
        <Select
          value={statusFilter}
          onChange={setStatusFilter}
          style={{ width: 150 }}
          options={[
            { value: 'all', label: 'Toate' },
            { value: 'paid', label: 'Plătite' },
            { value: 'unpaid', label: 'Neplătite' },
          ]}
        />
        <Select
          value={typeFilter}
          onChange={setTypeFilter}
          style={{ width: 180 }}
          options={[
            { value: 'all', label: 'Toate Tipurile' },
            ...UTILITY_TYPE_OPTIONS.map((opt) => ({
              value: opt.value,
              label: opt.label,
            })),
          ]}
        />
      </ListToolbar>

      <div className="pm-card-row-list">
        {isLoading ? (
          <div style={{ textAlign: 'center', padding: '48px' }}>
            <Spin size="large" />
          </div>
        ) : filteredInvoices.length === 0 ? (
          <EmptyState
            description={
              searchText || statusFilter !== 'all' || typeFilter !== 'all'
                ? 'Nu s-au găsit facturi care să corespundă criteriilor.'
                : 'Nu aveți facturi primite înregistrate. Adăugați prima factură de la furnizori.'
            }
            actionText={!searchText && statusFilter === 'all' && typeFilter === 'all' ? 'Adaugă Prima Factură' : null}
            onAction={!searchText && statusFilter === 'all' && typeFilter === 'all' ? showCreateModal : null}
          />
        ) : (
          filteredInvoices.map((invoice) => (
            <CardRow
              key={invoice.id}
              status={getRowStatus(invoice)}
              onClick={() => showEditModal(invoice)}
              actions={
                <>
                  <ActionButton
                    icon={<EditOutlined />}
                    onClick={() => showEditModal(invoice)}
                    variant="edit"
                    title="Editează"
                  />
                  {!invoice.is_paid && (
                    <Tooltip title="Marchează plătită" placement="top">
                      <Dropdown
                        menu={{ items: getPaymentMenuItems(invoice) }}
                        trigger={['click']}
                      >
                        <button
                          className="pm-action-btn pm-action-btn--view"
                          onClick={(e) => e.stopPropagation()}
                          aria-label="Marchează plătită"
                        >
                          <CheckOutlined />
                        </button>
                      </Dropdown>
                    </Tooltip>
                  )}
                  <ActionButton
                    icon={<DeleteOutlined />}
                    onClick={() => handleDelete(invoice)}
                    variant="delete"
                    title="Șterge"
                  />
                </>
              }
            >
              <CardRowPrimary>
                <CardRowTitle>{invoice.provider_name}</CardRowTitle>
                <Tag color={getTypeColor(invoice.utility_type)}>
                  {getUtilityTypeLabel(invoice.utility_type)}
                </Tag>
                <Tag color={invoice.is_paid ? 'green' : 'red'}>
                  {invoice.is_paid ? 'Plătită' : 'Neplătită'}
                </Tag>
              </CardRowPrimary>
              <CardRowSecondary>
                <CardRowDetail icon={<NumberOutlined />}>
                  {invoice.invoice_number}
                </CardRowDetail>
                <CardRowDetail icon={<EuroOutlined />}>
                  {formatCurrency(invoice.amount)}
                </CardRowDetail>
                <CardRowDetail icon={<CalendarOutlined />}>
                  {formatDate(invoice.invoice_date)}
                </CardRowDetail>
                {invoice.due_date && (
                  <CardRowDetail icon={<ShopOutlined />}>
                    Scadent: {formatDate(invoice.due_date)}
                  </CardRowDetail>
                )}
              </CardRowSecondary>
            </CardRow>
          ))
        )}
      </div>

      {/* Add/Edit Modal */}
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

      <Modal
        title="Selectați Data Plății"
        open={paidDateModalOpen}
        onOk={handleConfirmPaidDate}
        onCancel={() => {
          setPaidDateModalOpen(false);
          setSelectedInvoiceForPayment(null);
          setSelectedPaidDate(null);
        }}
        okText="Confirmă"
        cancelText="Anulează"
        confirmLoading={markPaidMutation.isPending}
      >
        <div style={{ marginBottom: 16 }}>
          <p>
            Furnizor: <strong>{selectedInvoiceForPayment?.provider_name}</strong>
          </p>
          <p>
            Factură: <strong>{selectedInvoiceForPayment?.invoice_number}</strong>
          </p>
          <p>
            Sumă: <strong>{formatCurrency(selectedInvoiceForPayment?.amount)}</strong>
          </p>
        </div>
        <Form.Item label="Data Plății" style={{ marginBottom: 0 }}>
          <DatePicker
            style={{ width: '100%' }}
            format="DD.MM.YYYY"
            value={selectedPaidDate}
            onChange={(date) => setSelectedPaidDate(date)}
            allowClear={false}
          />
        </Form.Item>
      </Modal>
    </div>
  );
};

export default ReceivedInvoices;
