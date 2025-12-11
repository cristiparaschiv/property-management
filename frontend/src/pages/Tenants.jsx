import React, { useState, useRef } from 'react';
import {
  Table,
  Button,
  Space,
  Modal,
  Form,
  Input,
  InputNumber,
  Switch,
  message,
  Popconfirm,
  Tag,
  Card,
  Dropdown,
  Typography,
} from 'antd';
import { PlusOutlined, EditOutlined, DeleteOutlined, MoreOutlined, PercentageOutlined, SearchOutlined } from '@ant-design/icons';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { tenantsService } from '../services/tenantsService';
import { formatEuro } from '../utils/formatters';
import { UTILITY_TYPE_OPTIONS } from '../constants/utilityTypes';
import EmptyState from '../components/EmptyState';

const { Title } = Typography;

const Tenants = () => {
  const [form] = Form.useForm();
  const [percentagesForm] = Form.useForm();
  const queryClient = useQueryClient();
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isPercentagesModalOpen, setIsPercentagesModalOpen] = useState(false);
  const [editingTenant, setEditingTenant] = useState(null);
  const [selectedTenant, setSelectedTenant] = useState(null);
  const searchInput = useRef(null);

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
      title: 'Nume',
      dataIndex: 'name',
      key: 'name',
      sorter: (a, b) => a.name.localeCompare(b.name),
      ...getColumnSearchProps('name', 'Caută după nume'),
    },
    {
      title: 'Email',
      dataIndex: 'email',
      key: 'email',
      ...getColumnSearchProps('email', 'Caută după email'),
    },
    {
      title: 'Telefon',
      dataIndex: 'phone',
      key: 'phone',
      ...getColumnSearchProps('phone', 'Caută după telefon'),
    },
    {
      title: 'Oraș',
      dataIndex: 'city',
      key: 'city',
      ...getColumnSearchProps('city', 'Caută după oraș'),
    },
    {
      title: 'Chirie (EUR)',
      dataIndex: 'rent_amount_eur',
      key: 'rent_amount_eur',
      render: (value) => formatEuro(value),
      sorter: (a, b) => a.rent_amount_eur - b.rent_amount_eur,
    },
    {
      title: 'Status',
      dataIndex: 'is_active',
      key: 'is_active',
      render: (isActive) => (
        <Tag color={isActive ? 'green' : 'red'}>
          {isActive ? 'Activ' : 'Inactiv'}
        </Tag>
      ),
      filters: [
        { text: 'Activ', value: true },
        { text: 'Inactiv', value: false },
      ],
      onFilter: (value, record) => record.is_active === value,
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
          {
            key: 'percentages',
            icon: <PercentageOutlined />,
            label: 'Procente',
            onClick: () => showPercentagesModal(record),
          },
          {
            key: 'deactivate',
            icon: <DeleteOutlined />,
            label: 'Dezactivează',
            danger: true,
            onClick: () => {
              Modal.confirm({
                title: 'Sigur doriți să dezactivați acest chiriaș?',
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

  const tenants = data?.data?.tenants || [];

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
        <Title level={2} style={{ margin: 0 }}>Chiriași</Title>
        <Button
          type="primary"
          icon={<PlusOutlined />}
          onClick={showCreateModal}
        >
          Adaugă Chiriaș
        </Button>
      </div>

      <Card>
        {tenants.length === 0 && !isLoading ? (
          <EmptyState
            description="Nu aveți încă chiriași înregistrați. Începeți prin a adăuga primul chiriaș."
            actionText="Adaugă Primul Chiriaș"
            onAction={showCreateModal}
          />
        ) : (
          <Table
            columns={columns}
            dataSource={tenants}
            rowKey="id"
            loading={isLoading}
            pagination={{ pageSize: 10 }}
          />
        )}
      </Card>

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
        <Form
          form={form}
          layout="vertical"
          initialValues={{ is_active: true }}
        >
          <Form.Item
            label="Nume"
            name="name"
            rules={[{ required: true, message: 'Numele este obligatoriu' }]}
          >
            <Input />
          </Form.Item>

          <Form.Item
            label="Email"
            name="email"
            rules={[{ type: 'email', message: 'Email invalid' }]}
          >
            <Input />
          </Form.Item>

          <Form.Item
            label="Telefon"
            name="phone"
          >
            <Input />
          </Form.Item>

          <Form.Item
            label="Adresă"
            name="address"
            rules={[{ required: true, message: 'Adresa este obligatorie' }]}
          >
            <Input />
          </Form.Item>

          <Form.Item
            label="Oraș"
            name="city"
            rules={[{ required: true, message: 'Orașul este obligatoriu' }]}
          >
            <Input />
          </Form.Item>

          <Form.Item
            label="Județ"
            name="county"
            rules={[{ required: true, message: 'Județul este obligatoriu' }]}
          >
            <Input />
          </Form.Item>

          <Form.Item
            label="Cod Poștal"
            name="postal_code"
          >
            <Input />
          </Form.Item>

          <Form.Item
            label="Chirie Lunară (EUR)"
            name="rent_amount_eur"
            rules={[{ required: true, message: 'Chiria este obligatorie' }]}
          >
            <InputNumber min={0} style={{ width: '100%' }} />
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
        <Form
          form={percentagesForm}
          layout="vertical"
        >
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
