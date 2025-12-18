import React, { useState, useMemo } from 'react';
import {
  Button,
  Modal,
  Form,
  Input,
  InputNumber,
  Switch,
  message,
  Tag,
  Spin,
  Select,
} from 'antd';
import {
  PlusOutlined,
  EditOutlined,
  DeleteOutlined,
  PercentageOutlined,
  UserOutlined,
  CheckCircleOutlined,
  ClockCircleOutlined,
  StopOutlined,
  MailOutlined,
  PhoneOutlined,
  EuroOutlined,
  CalendarOutlined,
} from '@ant-design/icons';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { tenantsService } from '../services/tenantsService';
import { formatEuro } from '../utils/formatters';
import { UTILITY_TYPE_OPTIONS } from '../constants/utilityTypes';
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

const Tenants = () => {
  const [form] = Form.useForm();
  const [percentagesForm] = Form.useForm();
  const queryClient = useQueryClient();
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isPercentagesModalOpen, setIsPercentagesModalOpen] = useState(false);
  const [editingTenant, setEditingTenant] = useState(null);
  const [selectedTenant, setSelectedTenant] = useState(null);
  const [searchText, setSearchText] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');

  const { data, isLoading } = useQuery({
    queryKey: ['tenants'],
    queryFn: () => tenantsService.getAll(),
  });

  const createMutation = useMutation({
    mutationFn: (values) => tenantsService.create(values),
    onSuccess: () => {
      message.success('Chiriaș adăugat cu succes!');
      queryClient.invalidateQueries(['tenants']);
      setIsModalOpen(false);
      form.resetFields();
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la adăugare');
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, values }) => tenantsService.update(id, values),
    onSuccess: () => {
      message.success('Chiriaș actualizat cu succes!');
      queryClient.invalidateQueries(['tenants']);
      setIsModalOpen(false);
      setEditingTenant(null);
      form.resetFields();
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la actualizare');
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (id) => tenantsService.delete(id),
    onSuccess: () => {
      message.success('Chiriaș dezactivat cu succes!');
      queryClient.invalidateQueries(['tenants']);
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la ștergere');
    },
  });

  const updatePercentagesMutation = useMutation({
    mutationFn: ({ id, percentages }) => tenantsService.updatePercentages(id, percentages),
    onSuccess: () => {
      message.success('Procente actualizate cu succes!');
      queryClient.invalidateQueries(['tenants']);
      setIsPercentagesModalOpen(false);
      percentagesForm.resetFields();
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la actualizare');
    },
  });

  const showCreateModal = () => {
    setEditingTenant(null);
    form.resetFields();
    setIsModalOpen(true);
  };

  const showEditModal = (tenant) => {
    setEditingTenant(tenant);
    form.setFieldsValue(tenant);
    setIsModalOpen(true);
  };

  const showPercentagesModal = (tenant) => {
    setSelectedTenant(tenant);
    const percentages = {};
    tenant.utility_percentages?.forEach((up) => {
      percentages[up.utility_type] = up.percentage;
    });
    percentagesForm.setFieldsValue(percentages);
    setIsPercentagesModalOpen(true);
  };

  const handleOk = () => {
    form.validateFields().then((values) => {
      if (editingTenant) {
        updateMutation.mutate({ id: editingTenant.id, values });
      } else {
        createMutation.mutate(values);
      }
    });
  };

  const handlePercentagesOk = () => {
    percentagesForm.validateFields().then((values) => {
      updatePercentagesMutation.mutate({ id: selectedTenant.id, percentages: values });
    });
  };

  const handleDelete = (tenant) => {
    Modal.confirm({
      title: 'Sigur doriți să dezactivați acest chiriaș?',
      content: `Chiriașul "${tenant.name}" va fi marcat ca inactiv.`,
      onOk: () => deleteMutation.mutate(tenant.id),
      okText: 'Da, dezactivează',
      cancelText: 'Anulează',
      okButtonProps: { danger: true },
    });
  };

  const tenants = data?.data?.tenants || [];

  // Calculate summary stats
  const stats = useMemo(() => {
    const total = tenants.length;
    const active = tenants.filter((t) => t.is_active).length;
    const inactive = tenants.filter((t) => !t.is_active).length;
    // For "expiring soon" we'd need contract_end date - placeholder for now
    const expiring = 0;
    return { total, active, inactive, expiring };
  }, [tenants]);

  // Filter tenants
  const filteredTenants = useMemo(() => {
    return tenants.filter((tenant) => {
      const matchesSearch =
        !searchText ||
        tenant.name?.toLowerCase().includes(searchText.toLowerCase()) ||
        tenant.email?.toLowerCase().includes(searchText.toLowerCase()) ||
        tenant.phone?.includes(searchText);

      const matchesStatus =
        statusFilter === 'all' ||
        (statusFilter === 'active' && tenant.is_active) ||
        (statusFilter === 'inactive' && !tenant.is_active);

      return matchesSearch && matchesStatus;
    });
  }, [tenants, searchText, statusFilter]);

  // Get row status based on tenant state
  const getRowStatus = (tenant) => {
    if (!tenant.is_active) return 'error';
    // Could add warning for expiring contracts
    return 'success';
  };

  return (
    <div>
      <ListPageHeader
        title="Chiriași"
        subtitle="Gestionează chiriașii și procentele de utilități"
        action={
          <Button type="primary" icon={<PlusOutlined />} onClick={showCreateModal}>
            Adaugă Chiriaș
          </Button>
        }
      />

      <ListSummaryCards>
        <SummaryCard
          icon={<UserOutlined />}
          value={stats.total}
          label="Total Chiriași"
          variant="default"
        />
        <SummaryCard
          icon={<CheckCircleOutlined />}
          value={stats.active}
          label="Activi"
          variant="success"
        />
        <SummaryCard
          icon={<ClockCircleOutlined />}
          value={stats.expiring}
          label="Expiră curând"
          variant="warning"
        />
        <SummaryCard
          icon={<StopOutlined />}
          value={stats.inactive}
          label="Inactivi"
          variant="error"
        />
      </ListSummaryCards>

      <ListToolbar>
        <Input.Search
          placeholder="Caută după nume, email sau telefon..."
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
            { value: 'active', label: 'Activi' },
            { value: 'inactive', label: 'Inactivi' },
          ]}
        />
      </ListToolbar>

      <div className="pm-card-row-list">
        {isLoading ? (
          <div style={{ textAlign: 'center', padding: '48px' }}>
            <Spin size="large" />
          </div>
        ) : filteredTenants.length === 0 ? (
          <EmptyState
            description={
              searchText || statusFilter !== 'all'
                ? 'Nu s-au găsit chiriași care să corespundă criteriilor.'
                : 'Nu aveți încă chiriași înregistrați. Începeți prin a adăuga primul chiriaș.'
            }
            actionText={!searchText && statusFilter === 'all' ? 'Adaugă Primul Chiriaș' : null}
            onAction={!searchText && statusFilter === 'all' ? showCreateModal : null}
          />
        ) : (
          filteredTenants.map((tenant) => (
            <CardRow
              key={tenant.id}
              status={getRowStatus(tenant)}
              onClick={() => showEditModal(tenant)}
              actions={
                <>
                  <ActionButton
                    icon={<EditOutlined />}
                    onClick={() => showEditModal(tenant)}
                    variant="edit"
                    title="Editează"
                  />
                  <ActionButton
                    icon={<PercentageOutlined />}
                    onClick={() => showPercentagesModal(tenant)}
                    variant="view"
                    title="Procente utilități"
                  />
                  <ActionButton
                    icon={<DeleteOutlined />}
                    onClick={() => handleDelete(tenant)}
                    variant="delete"
                    title="Dezactivează"
                  />
                </>
              }
            >
              <CardRowPrimary>
                <CardRowTitle>{tenant.name}</CardRowTitle>
                <Tag color={tenant.is_active ? 'green' : 'default'}>
                  {tenant.is_active ? 'Activ' : 'Inactiv'}
                </Tag>
              </CardRowPrimary>
              <CardRowSecondary>
                {tenant.email && (
                  <CardRowDetail icon={<MailOutlined />}>{tenant.email}</CardRowDetail>
                )}
                {tenant.phone && (
                  <CardRowDetail icon={<PhoneOutlined />}>{tenant.phone}</CardRowDetail>
                )}
                {tenant.rent_amount_eur > 0 && (
                  <CardRowDetail icon={<EuroOutlined />}>
                    {formatEuro(tenant.rent_amount_eur)}/lună
                  </CardRowDetail>
                )}
                {tenant.city && (
                  <CardRowDetail icon={<CalendarOutlined />}>{tenant.city}</CardRowDetail>
                )}
              </CardRowSecondary>
            </CardRow>
          ))
        )}
      </div>

      {/* Add/Edit Tenant Modal */}
      <Modal
        title={editingTenant ? 'Editare Chiriaș' : 'Adăugare Chiriaș'}
        open={isModalOpen}
        onOk={handleOk}
        onCancel={() => {
          setIsModalOpen(false);
          setEditingTenant(null);
          form.resetFields();
        }}
        width={700}
        okText="Salvează"
        cancelText="Anulează"
        confirmLoading={createMutation.isPending || updateMutation.isPending}
      >
        <Form form={form} layout="vertical" initialValues={{ is_active: true }} validateTrigger={['onChange', 'onBlur']}>
          <Form.Item
            label="Nume"
            name="name"
            rules={[
              { required: true, message: 'Numele este obligatoriu' },
              { min: 2, message: 'Numele trebuie să aibă minim 2 caractere' }
            ]}
            hasFeedback
          >
            <Input prefix={<UserOutlined style={{ color: 'rgba(0,0,0,.25)' }} />} placeholder="ex: Ion Popescu" />
          </Form.Item>

          <Form.Item
            label="Email"
            name="email"
            rules={[
              { type: 'email', message: 'Email invalid' },
              { pattern: /^[^\s@]+@[^\s@]+\.[^\s@]+$/, message: 'Format email invalid' }
            ]}
            hasFeedback
          >
            <Input prefix={<MailOutlined style={{ color: 'rgba(0,0,0,.25)' }} />} placeholder="ex: ion@exemplu.ro" />
          </Form.Item>

          <Form.Item
            label="Telefon"
            name="phone"
            rules={[
              { pattern: /^[0-9+\-\s()]+$/, message: 'Număr de telefon invalid' }
            ]}
            hasFeedback
          >
            <Input prefix={<PhoneOutlined style={{ color: 'rgba(0,0,0,.25)' }} />} placeholder="ex: 0722 123 456" />
          </Form.Item>

          <Form.Item
            label="Adresă"
            name="address"
            rules={[
              { required: true, message: 'Adresa este obligatorie' },
              { min: 5, message: 'Adresa trebuie să fie mai detaliată' }
            ]}
            hasFeedback
          >
            <Input placeholder="ex: Str. Exemplu nr. 10, ap. 5" />
          </Form.Item>

          <Form.Item
            label="Oraș"
            name="city"
            rules={[
              { required: true, message: 'Orașul este obligatoriu' },
              { min: 2, message: 'Numele orașului este prea scurt' }
            ]}
            hasFeedback
          >
            <Input placeholder="ex: București" />
          </Form.Item>

          <Form.Item
            label="Județ"
            name="county"
            rules={[
              { required: true, message: 'Județul este obligatoriu' },
              { min: 2, message: 'Numele județului este prea scurt' }
            ]}
            hasFeedback
          >
            <Input placeholder="ex: Ilfov" />
          </Form.Item>

          <Form.Item
            label="Cod Poștal"
            name="postal_code"
            rules={[
              { pattern: /^\d{6}$/, message: 'Codul poștal trebuie să aibă 6 cifre' }
            ]}
            hasFeedback
          >
            <Input placeholder="ex: 012345" maxLength={6} />
          </Form.Item>

          <Form.Item
            label="Chirie Lunară (EUR)"
            name="rent_amount_eur"
            rules={[
              { required: true, message: 'Chiria este obligatorie' },
              { type: 'number', min: 0, message: 'Chiria nu poate fi negativă' }
            ]}
            hasFeedback
          >
            <InputNumber min={0} style={{ width: '100%' }} placeholder="ex: 500" prefix={<EuroOutlined />} />
          </Form.Item>

          <Form.Item label="Activ" name="is_active" valuePropName="checked">
            <Switch checkedChildren="Da" unCheckedChildren="Nu" />
          </Form.Item>
        </Form>
      </Modal>

      {/* Percentages Modal */}
      <Modal
        title={`Procente Utilități - ${selectedTenant?.name}`}
        open={isPercentagesModalOpen}
        onOk={handlePercentagesOk}
        onCancel={() => {
          setIsPercentagesModalOpen(false);
          percentagesForm.resetFields();
        }}
        okText="Salvează"
        cancelText="Anulează"
        confirmLoading={updatePercentagesMutation.isPending}
      >
        <Form form={percentagesForm} layout="vertical">
          {UTILITY_TYPE_OPTIONS.map((option) => (
            <Form.Item
              key={option.value}
              label={`${option.label} (%)`}
              name={option.value}
              rules={[{ type: 'number', min: 0, max: 100 }]}
            >
              <InputNumber min={0} max={100} style={{ width: '100%' }} />
            </Form.Item>
          ))}
        </Form>
      </Modal>
    </div>
  );
};

export default Tenants;
