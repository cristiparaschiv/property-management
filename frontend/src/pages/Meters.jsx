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
  DashboardOutlined,
  CheckCircleOutlined,
  ClusterOutlined,
  UserOutlined,
  EnvironmentOutlined,
  NumberOutlined,
} from '@ant-design/icons';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { metersService } from '../services/metersService';
import { tenantsService } from '../services/tenantsService';
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

const Meters = () => {
  const [form] = Form.useForm();
  const queryClient = useQueryClient();
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingMeter, setEditingMeter] = useState(null);
  const [searchText, setSearchText] = useState('');
  const [typeFilter, setTypeFilter] = useState('all');

  const { data: metersData, isLoading } = useQuery({
    queryKey: ['meters'],
    queryFn: () => metersService.getAll(),
  });

  const { data: tenantsData } = useQuery({
    queryKey: ['tenants'],
    queryFn: () => tenantsService.getAll(),
  });

  const createMutation = useMutation({
    mutationFn: (values) => metersService.create(values),
    onSuccess: () => {
      message.success('Contor adăugat cu succes!');
      queryClient.invalidateQueries(['meters']);
      setIsModalOpen(false);
      form.resetFields();
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la adăugare');
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, values }) => metersService.update(id, values),
    onSuccess: () => {
      message.success('Contor actualizat cu succes!');
      queryClient.invalidateQueries(['meters']);
      setIsModalOpen(false);
      setEditingMeter(null);
      form.resetFields();
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la actualizare');
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (id) => metersService.delete(id),
    onSuccess: () => {
      message.success('Contor șters cu succes!');
      queryClient.invalidateQueries(['meters']);
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la ștergere');
    },
  });

  const showCreateModal = () => {
    setEditingMeter(null);
    form.resetFields();
    setIsModalOpen(true);
  };

  const showEditModal = (meter) => {
    setEditingMeter(meter);
    form.setFieldsValue(meter);
    setIsModalOpen(true);
  };

  const handleOk = () => {
    form.validateFields().then((values) => {
      if (editingMeter) {
        updateMutation.mutate({ id: editingMeter.id, values });
      } else {
        createMutation.mutate(values);
      }
    });
  };

  const handleDelete = (meter) => {
    Modal.confirm({
      title: 'Sigur doriți să ștergeți acest contor?',
      content: `Contorul "${meter.name}" va fi șters permanent.`,
      onOk: () => deleteMutation.mutate(meter.id),
      okText: 'Da, șterge',
      cancelText: 'Anulează',
      okButtonProps: { danger: true },
    });
  };

  const meters = metersData?.data || [];
  const tenants = tenantsData?.data?.tenants || [];

  // Calculate summary stats
  const stats = useMemo(() => {
    const total = meters.length;
    const active = meters.filter((m) => m.is_active).length;
    const general = meters.filter((m) => m.is_general).length;
    const individual = meters.filter((m) => !m.is_general).length;
    return { total, active, general, individual };
  }, [meters]);

  // Filter meters
  const filteredMeters = useMemo(() => {
    return meters.filter((meter) => {
      const matchesSearch =
        !searchText ||
        meter.name?.toLowerCase().includes(searchText.toLowerCase()) ||
        meter.tenant_name?.toLowerCase().includes(searchText.toLowerCase()) ||
        meter.location?.toLowerCase().includes(searchText.toLowerCase());

      const matchesType =
        typeFilter === 'all' ||
        (typeFilter === 'general' && meter.is_general) ||
        (typeFilter === 'individual' && !meter.is_general);

      return matchesSearch && matchesType;
    });
  }, [meters, searchText, typeFilter]);

  // Get row status based on meter state
  const getRowStatus = (meter) => {
    if (!meter.is_active) return 'error';
    if (meter.is_general) return 'info';
    return 'success';
  };

  return (
    <div>
      <ListPageHeader
        title="Contoare"
        subtitle="Gestionează contoarele de utilități"
        action={
          <Button type="primary" icon={<PlusOutlined />} onClick={showCreateModal}>
            Adaugă Contor
          </Button>
        }
      />

      <ListSummaryCards>
        <SummaryCard
          icon={<DashboardOutlined />}
          value={stats.total}
          label="Total Contoare"
          variant="default"
        />
        <SummaryCard
          icon={<CheckCircleOutlined />}
          value={stats.active}
          label="Active"
          variant="success"
        />
        <SummaryCard
          icon={<ClusterOutlined />}
          value={stats.general}
          label="Generale"
          variant="info"
        />
        <SummaryCard
          icon={<UserOutlined />}
          value={stats.individual}
          label="Individuale"
          variant="warning"
        />
      </ListSummaryCards>

      <ListToolbar>
        <Input.Search
          placeholder="Caută după nume, chiriaș sau locație..."
          allowClear
          onChange={(e) => setSearchText(e.target.value)}
          style={{ maxWidth: 320 }}
        />
        <Select
          value={typeFilter}
          onChange={setTypeFilter}
          style={{ width: 150 }}
          options={[
            { value: 'all', label: 'Toate' },
            { value: 'general', label: 'Generale' },
            { value: 'individual', label: 'Individuale' },
          ]}
        />
      </ListToolbar>

      <div className="pm-card-row-list">
        {isLoading ? (
          <div style={{ textAlign: 'center', padding: '48px' }}>
            <Spin size="large" />
          </div>
        ) : filteredMeters.length === 0 ? (
          <EmptyState
            description={
              searchText || typeFilter !== 'all'
                ? 'Nu s-au găsit contoare care să corespundă criteriilor.'
                : 'Nu aveți contoare înregistrate. Adăugați primul contor pentru a începe.'
            }
            actionText={!searchText && typeFilter === 'all' ? 'Adaugă Primul Contor' : null}
            onAction={!searchText && typeFilter === 'all' ? showCreateModal : null}
          />
        ) : (
          filteredMeters.map((meter) => (
            <CardRow
              key={meter.id}
              status={getRowStatus(meter)}
              onClick={() => showEditModal(meter)}
              actions={
                <>
                  <ActionButton
                    icon={<EditOutlined />}
                    onClick={() => showEditModal(meter)}
                    variant="edit"
                    title="Editează"
                  />
                  {!meter.is_general && (
                    <ActionButton
                      icon={<DeleteOutlined />}
                      onClick={() => handleDelete(meter)}
                      variant="delete"
                      title="Șterge"
                    />
                  )}
                </>
              }
            >
              <CardRowPrimary>
                <CardRowTitle>{meter.name}</CardRowTitle>
                <Tag color={meter.is_general ? 'blue' : 'green'}>
                  {meter.is_general ? 'General' : 'Individual'}
                </Tag>
                <Tag color={meter.is_active ? 'green' : 'default'}>
                  {meter.is_active ? 'Activ' : 'Inactiv'}
                </Tag>
              </CardRowPrimary>
              <CardRowSecondary>
                {meter.tenant_name && (
                  <CardRowDetail icon={<UserOutlined />}>
                    {meter.tenant_name}
                  </CardRowDetail>
                )}
                {meter.location && (
                  <CardRowDetail icon={<EnvironmentOutlined />}>
                    {meter.location}
                  </CardRowDetail>
                )}
                {meter.serial_number && (
                  <CardRowDetail icon={<NumberOutlined />}>
                    S/N: {meter.serial_number}
                  </CardRowDetail>
                )}
              </CardRowSecondary>
            </CardRow>
          ))
        )}
      </div>

      {/* Add/Edit Modal */}
      <Modal
        title={editingMeter ? 'Editare Contor' : 'Adăugare Contor'}
        open={isModalOpen}
        onOk={handleOk}
        onCancel={() => {
          setIsModalOpen(false);
          setEditingMeter(null);
          form.resetFields();
        }}
        width={600}
        okText="Salvează"
        cancelText="Anulează"
        confirmLoading={createMutation.isPending || updateMutation.isPending}
      >
        <Form
          form={form}
          layout="vertical"
          initialValues={{ is_active: true, is_general: false }}
        >
          <Form.Item
            label="Nume"
            name="name"
            rules={[{ required: true, message: 'Numele este obligatoriu' }]}
          >
            <Input placeholder="Ex: Contor Apartament 1" />
          </Form.Item>

          <Form.Item
            label="Chiriaș"
            name="tenant_id"
          >
            <Select placeholder="Selectați chiriașul" allowClear>
              {tenants.map((tenant) => (
                <Option key={tenant.id} value={tenant.id}>
                  {tenant.name}
                </Option>
              ))}
            </Select>
          </Form.Item>

          <Form.Item
            label="Locație"
            name="location"
          >
            <Input placeholder="Ex: Apartament 1, Etaj 2" />
          </Form.Item>

          <Form.Item
            label="Număr Serie"
            name="serial_number"
          >
            <Input />
          </Form.Item>

          <Form.Item
            label="Contor General"
            name="is_general"
            valuePropName="checked"
          >
            <Switch />
          </Form.Item>

          <Form.Item
            label="Activ"
            name="is_active"
            valuePropName="checked"
          >
            <Switch />
          </Form.Item>
        </Form>
      </Modal>
    </div>
  );
};

export default Meters;
