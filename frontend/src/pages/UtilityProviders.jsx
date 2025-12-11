import React, { useState, useRef } from 'react';
import {
  Table,
  Button,
  Space,
  Modal,
  Form,
  Input,
  Select,
  Switch,
  message,
  Popconfirm,
  Tag,
  Card,
  Dropdown,
  Typography,
} from 'antd';
import { PlusOutlined, EditOutlined, DeleteOutlined, MoreOutlined, SearchOutlined } from '@ant-design/icons';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { utilityProvidersService } from '../services/utilityProvidersService';
import { UTILITY_TYPE_OPTIONS, getUtilityTypeLabel } from '../constants/utilityTypes';
import EmptyState from '../components/EmptyState';

const { Title } = Typography;

const { Option } = Select;

const UtilityProviders = () => {
  const [form] = Form.useForm();
  const queryClient = useQueryClient();
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingProvider, setEditingProvider] = useState(null);
  const searchInput = useRef(null);

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
      title: 'Tip',
      dataIndex: 'type',
      key: 'type',
      render: (type) => <Tag color="blue">{getUtilityTypeLabel(type)}</Tag>,
      filters: UTILITY_TYPE_OPTIONS.map(option => ({
        text: option.label,
        value: option.value,
      })),
      onFilter: (value, record) => record.type === value,
    },
    {
      title: 'Telefon',
      dataIndex: 'phone',
      key: 'phone',
      ...getColumnSearchProps('phone', 'Caută după telefon'),
    },
    {
      title: 'Email',
      dataIndex: 'email',
      key: 'email',
      ...getColumnSearchProps('email', 'Caută după email'),
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
            key: 'deactivate',
            icon: <DeleteOutlined />,
            label: 'Dezactivează',
            danger: true,
            onClick: () => {
              Modal.confirm({
                title: 'Sigur doriți să dezactivați acest furnizor?',
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

  const providers = data?.data || [];

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
        <Title level={2} style={{ margin: 0 }}>Furnizori Utilități</Title>
        <Button
          type="primary"
          icon={<PlusOutlined />}
          onClick={showCreateModal}
        >
          Adaugă Furnizor
        </Button>
      </div>

      <Card>
        {providers.length === 0 && !isLoading ? (
          <EmptyState
            description="Nu aveți furnizori de utilități înregistrați. Adăugați primul furnizor pentru a începe."
            actionText="Adaugă Primul Furnizor"
            onAction={showCreateModal}
          />
        ) : (
          <Table
            columns={columns}
            dataSource={providers}
            rowKey="id"
            loading={isLoading}
            pagination={{ pageSize: 10 }}
          />
        )}
      </Card>

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

          <Form.Item
            label="Telefon"
            name="phone"
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
            label="Adresă"
            name="address"
          >
            <Input />
          </Form.Item>

          <Form.Item
            label="Website"
            name="website"
          >
            <Input />
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

export default UtilityProviders;
