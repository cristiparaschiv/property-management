import React, { useState, useMemo } from 'react';
import {
  Button,
  Modal,
  Form,
  Input,
  Select,
  Switch,
  message,
  Tag,
  Spin,
} from 'antd';
import {
  PlusOutlined,
  EditOutlined,
  DeleteOutlined,
  ShopOutlined,
  CheckCircleOutlined,
  ThunderboltOutlined,
  AppstoreOutlined,
  PhoneOutlined,
  MailOutlined,
  GlobalOutlined,
} from '@ant-design/icons';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { utilityProvidersService } from '../services/utilityProvidersService';
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

const { Option } = Select;

const UtilityProviders = () => {
  const [form] = Form.useForm();
  const queryClient = useQueryClient();
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingProvider, setEditingProvider] = useState(null);
  const [searchText, setSearchText] = useState('');
  const [typeFilter, setTypeFilter] = useState('all');

  const { data, isLoading } = useQuery({
    queryKey: ['utility-providers'],
    queryFn: () => utilityProvidersService.getAll(),
  });

  const createMutation = useMutation({
    mutationFn: (values) => utilityProvidersService.create(values),
    onSuccess: () => {
      message.success('Furnizor adăugat cu succes!');
      queryClient.invalidateQueries(['utility-providers']);
      setIsModalOpen(false);
      form.resetFields();
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la adăugare');
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, values }) => utilityProvidersService.update(id, values),
    onSuccess: () => {
      message.success('Furnizor actualizat cu succes!');
      queryClient.invalidateQueries(['utility-providers']);
      setIsModalOpen(false);
      setEditingProvider(null);
      form.resetFields();
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la actualizare');
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (id) => utilityProvidersService.delete(id),
    onSuccess: () => {
      message.success('Furnizor dezactivat cu succes!');
      queryClient.invalidateQueries(['utility-providers']);
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la ștergere');
    },
  });

  const showCreateModal = () => {
    setEditingProvider(null);
    form.resetFields();
    setIsModalOpen(true);
  };

  const showEditModal = (provider) => {
    setEditingProvider(provider);
    form.setFieldsValue(provider);
    setIsModalOpen(true);
  };

  const handleOk = () => {
    form.validateFields().then((values) => {
      if (editingProvider) {
        updateMutation.mutate({ id: editingProvider.id, values });
      } else {
        createMutation.mutate(values);
      }
    });
  };

  const handleDelete = (provider) => {
    Modal.confirm({
      title: 'Sigur doriți să dezactivați acest furnizor?',
      content: `Furnizorul "${provider.name}" va fi marcat ca inactiv.`,
      onOk: () => deleteMutation.mutate(provider.id),
      okText: 'Da, dezactivează',
      cancelText: 'Anulează',
      okButtonProps: { danger: true },
    });
  };

  const providers = data?.data || [];

  // Calculate summary stats
  const stats = useMemo(() => {
    const total = providers.length;
    const active = providers.filter((p) => p.is_active).length;
    const electricity = providers.filter((p) => p.type === 'electricity').length;
    const other = providers.filter((p) => p.type !== 'electricity').length;
    return { total, active, electricity, other };
  }, [providers]);

  // Filter providers
  const filteredProviders = useMemo(() => {
    return providers.filter((provider) => {
      const matchesSearch =
        !searchText ||
        provider.name?.toLowerCase().includes(searchText.toLowerCase()) ||
        provider.email?.toLowerCase().includes(searchText.toLowerCase()) ||
        provider.phone?.includes(searchText);

      const matchesType =
        typeFilter === 'all' || provider.type === typeFilter;

      return matchesSearch && matchesType;
    });
  }, [providers, searchText, typeFilter]);

  // Get row status based on provider state
  const getRowStatus = (provider) => {
    if (!provider.is_active) return 'error';
    return 'success';
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
        title="Furnizori Utilități"
        subtitle="Gestionează furnizorii de utilități pentru proprietăți"
        action={
          <Button type="primary" icon={<PlusOutlined />} onClick={showCreateModal}>
            Adaugă Furnizor
          </Button>
        }
      />

      <ListSummaryCards>
        <SummaryCard
          icon={<ShopOutlined />}
          value={stats.total}
          label="Total Furnizori"
          variant="default"
        />
        <SummaryCard
          icon={<CheckCircleOutlined />}
          value={stats.active}
          label="Activi"
          variant="success"
        />
        <SummaryCard
          icon={<ThunderboltOutlined />}
          value={stats.electricity}
          label="Electricitate"
          variant="warning"
        />
        <SummaryCard
          icon={<AppstoreOutlined />}
          value={stats.other}
          label="Alte Tipuri"
          variant="info"
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
        ) : filteredProviders.length === 0 ? (
          <EmptyState
            description={
              searchText || typeFilter !== 'all'
                ? 'Nu s-au găsit furnizori care să corespundă criteriilor.'
                : 'Nu aveți furnizori de utilități înregistrați. Adăugați primul furnizor pentru a începe.'
            }
            actionText={!searchText && typeFilter === 'all' ? 'Adaugă Primul Furnizor' : null}
            onAction={!searchText && typeFilter === 'all' ? showCreateModal : null}
          />
        ) : (
          filteredProviders.map((provider) => (
            <CardRow
              key={provider.id}
              status={getRowStatus(provider)}
              onClick={() => showEditModal(provider)}
              actions={
                <>
                  <ActionButton
                    icon={<EditOutlined />}
                    onClick={() => showEditModal(provider)}
                    variant="edit"
                    title="Editează"
                  />
                  <ActionButton
                    icon={<DeleteOutlined />}
                    onClick={() => handleDelete(provider)}
                    variant="delete"
                    title="Dezactivează"
                  />
                </>
              }
            >
              <CardRowPrimary>
                <CardRowTitle>{provider.name}</CardRowTitle>
                <Tag color={getTypeColor(provider.type)}>
                  {getUtilityTypeLabel(provider.type)}
                </Tag>
                <Tag color={provider.is_active ? 'green' : 'default'}>
                  {provider.is_active ? 'Activ' : 'Inactiv'}
                </Tag>
              </CardRowPrimary>
              <CardRowSecondary>
                {provider.phone && (
                  <CardRowDetail icon={<PhoneOutlined />}>{provider.phone}</CardRowDetail>
                )}
                {provider.email && (
                  <CardRowDetail icon={<MailOutlined />}>{provider.email}</CardRowDetail>
                )}
                {provider.website && (
                  <CardRowDetail icon={<GlobalOutlined />}>{provider.website}</CardRowDetail>
                )}
              </CardRowSecondary>
            </CardRow>
          ))
        )}
      </div>

      {/* Add/Edit Modal */}
      <Modal
        title={editingProvider ? 'Editare Furnizor' : 'Adăugare Furnizor'}
        open={isModalOpen}
        onOk={handleOk}
        onCancel={() => {
          setIsModalOpen(false);
          setEditingProvider(null);
          form.resetFields();
        }}
        width={600}
        okText="Salvează"
        cancelText="Anulează"
        confirmLoading={createMutation.isPending || updateMutation.isPending}
      >
        <Form form={form} layout="vertical" initialValues={{ is_active: true }}>
          <Form.Item
            label="Nume"
            name="name"
            rules={[{ required: true, message: 'Numele este obligatoriu' }]}
          >
            <Input />
          </Form.Item>

          <Form.Item
            label="Tip"
            name="type"
            rules={[{ required: true, message: 'Tipul este obligatoriu' }]}
          >
            <Select placeholder="Selectați tipul">
              {UTILITY_TYPE_OPTIONS.map((option) => (
                <Option key={option.value} value={option.value}>
                  {option.label}
                </Option>
              ))}
            </Select>
          </Form.Item>

          <Form.Item label="Telefon" name="phone">
            <Input />
          </Form.Item>

          <Form.Item
            label="Email"
            name="email"
            rules={[{ type: 'email', message: 'Email invalid' }]}
          >
            <Input />
          </Form.Item>

          <Form.Item label="Adresă" name="address">
            <Input />
          </Form.Item>

          <Form.Item label="Website" name="website">
            <Input />
          </Form.Item>

          <Form.Item label="Activ" name="is_active" valuePropName="checked">
            <Switch />
          </Form.Item>
        </Form>
      </Modal>
    </div>
  );
};

export default UtilityProviders;
